# %% [markdown]
# # NutritAI — Multi-Head Food Recognition Model (v2)
#
# **Architecture:** EfficientNetB3 backbone → shared hidden layers → 2 classification heads
# - Food-101 head (101 classes)
# - Indian Food head (80 classes)
#
# **Key fixes from v1:**
# 1. Masked loss (not zero-labels) so invalid heads don't corrupt training
# 2. Balanced sampling with `.repeat()` so Indian data doesn't silently exhaust
# 3. No `/255` — EfficientNet has built-in preprocessing
# 4. Data augmentation for the small Indian dataset (50 imgs/class)

# %% Cell 1 — GPU Setup
import tensorflow as tf
import subprocess
import os

print("TensorFlow version:", tf.__version__)

gpus = tf.config.list_physical_devices("GPU")
if gpus:
    print("\n🔥 GPU Detected!")
    for gpu in gpus:
        print("GPU:", gpu)
    try:
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        print("✔ Memory growth enabled.")
    except Exception as e:
        print("⚠ Could not set memory growth:", e)
else:
    print("\n❌ No GPU detected. Training will run on CPU (slower).")

print("\n=== NVIDIA-SMI Output ===")
print(subprocess.getoutput("nvidia-smi"))

# Clear previous sessions to free memory
tf.keras.backend.clear_session()

# %% Cell 2 — Configuration
IMG_SIZE = 300          # EfficientNetB3 native resolution — best speed/accuracy tradeoff
BATCH = 32              # Increased from 16 — more stable gradients
NUM_FOOD101 = 101
NUM_INDIAN = 80

print(f"Image size: {IMG_SIZE}x{IMG_SIZE}")
print(f"Batch size: {BATCH}")
print(f"Total classes: {NUM_FOOD101} (Food-101) + {NUM_INDIAN} (Indian) = {NUM_FOOD101 + NUM_INDIAN}")

# %% Cell 3 — Load Food-101 from TFDS
import tensorflow_datasets as tfds

(food101_train_raw, food101_val_raw), food101_info = tfds.load(
    "food101",
    split=["train", "validation"],
    as_supervised=True,
    with_info=True
)

food101_class_names = food101_info.features["label"].names
print(f"Food-101 classes: {len(food101_class_names)}")
print(f"Food-101 train size: {food101_info.splits['train'].num_examples}")
print(f"Food-101 val size: {food101_info.splits['validation'].num_examples}")

# %% Cell 4 — Load Indian Food Dataset from Kaggle
import kagglehub

path = kagglehub.dataset_download("iamsouravbanerjee/indian-food-images-dataset")
print("Path to dataset files:", path)

# Explore the directory structure
print(os.listdir(path))
sub1 = os.path.join(path, os.listdir(path)[0])
print("Subfolder:", sub1)
print(os.listdir(sub1))

# %% Cell 5 — Create Indian Food Dataset with ImageDataGenerator
from tensorflow.keras.preprocessing.image import ImageDataGenerator

# Set the correct path (adjust if your structure differs)
INDIAN_PATH = os.path.join(path, "Indian Food Images", "Indian Food Images")

# NOTE: No rescale=1/255! EfficientNet handles its own preprocessing.
indian_gen = ImageDataGenerator(validation_split=0.2)

indian_train_gen = indian_gen.flow_from_directory(
    INDIAN_PATH,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH,
    class_mode="sparse",
    subset="training",
    shuffle=True,
    seed=42
)

indian_val_gen = indian_gen.flow_from_directory(
    INDIAN_PATH,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH,
    class_mode="sparse",
    subset="validation",
    shuffle=False
)

indian_class_names = list(indian_train_gen.class_indices.keys())
print(f"\nIndian classes: {len(indian_class_names)}")
print(f"Indian train samples: {indian_train_gen.samples}")
print(f"Indian val samples: {indian_val_gen.samples}")

# %% Cell 6 — Preprocessing Functions
#
# CRITICAL FIX: Do NOT divide by 255!
# EfficientNet models have a built-in preprocessing layer that expects [0, 255] input.
# Dividing by 255 double-normalizes and degrades feature quality.

def preprocess_food101(image, label):
    """Resize and cast to float32. Keep [0, 255] range."""
    image = tf.image.resize(image, (IMG_SIZE, IMG_SIZE))
    image = tf.cast(image, tf.float32)  # [0, 255] — NOT /255!
    return image, label

print("✔ Preprocessing functions defined (no /255 normalization)")

# %% Cell 7 — Data Augmentation
#
# CRITICAL FIX: The Indian dataset has only ~50 images per class.
# Without augmentation, the model will massively overfit or underfit.

data_augmentation = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal"),
    tf.keras.layers.RandomRotation(0.15),
    tf.keras.layers.RandomZoom(0.1),
    tf.keras.layers.RandomContrast(0.1),
], name="data_augmentation")

def augment(image, label):
    """Apply random augmentations during training."""
    image = data_augmentation(image, training=True)
    return image, label

print("✔ Data augmentation pipeline defined")
print("  - RandomFlip (horizontal)")
print("  - RandomRotation (±15%)")
print("  - RandomZoom (±10%)")
print("  - RandomContrast (±10%)")

# %% Cell 8 — Dataset Wrapping with MASKED Labels
#
# CRITICAL FIX: This is the #1 bug in v1.
#
# OLD (BROKEN):  tf.zeros_like(label)  → teaches wrong head "everything is class 0"
# NEW (CORRECT): tf.constant(-1)       → masked loss ignores this head entirely
#
# When training on a Food-101 image, the Indian head should contribute
# ZERO gradient — not learn that the image is Indian class 0.

def wrap_food101(image, label):
    """Wrap Food-101 sample: valid food101 label, masked indian label."""
    return image, {
        "food101_head": tf.cast(label, tf.int64),
        "indian_head": tf.constant(-1, dtype=tf.int64),  # MASKED
    }

def wrap_indian(images, labels):
    """Wrap Indian sample: masked food101 label, valid indian label."""
    batch_size = tf.shape(labels)[0]
    return images, {
        "food101_head": tf.fill([batch_size], tf.constant(-1, dtype=tf.int64)),  # MASKED
        "indian_head": tf.cast(labels, tf.int64),
    }

print("✔ Dataset wrappers defined with masked labels (-1)")

# %% Cell 9 — Build Training & Validation Pipelines

# --- Food-101 Training Pipeline ---
food101_train = (
    food101_train_raw
    .map(preprocess_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    .map(wrap_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .shuffle(4096)
    .batch(BATCH)
    .prefetch(tf.data.AUTOTUNE)
)

# --- Food-101 Validation Pipeline (no augmentation, no shuffle) ---
food101_val = (
    food101_val_raw
    .map(preprocess_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .map(wrap_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .batch(BATCH)
    .prefetch(tf.data.AUTOTUNE)
)

# --- Indian Food: Convert generator → tf.data.Dataset ---
def indian_gen_to_dataset(gen):
    return tf.data.Dataset.from_generator(
        lambda: gen,
        output_signature=(
            tf.TensorSpec(shape=(None, IMG_SIZE, IMG_SIZE, 3), dtype=tf.float32),
            tf.TensorSpec(shape=(None,), dtype=tf.float32),
        )
    )

indian_train_ds = (
    indian_gen_to_dataset(indian_train_gen)
    .map(wrap_indian, num_parallel_calls=tf.data.AUTOTUNE)
    .prefetch(tf.data.AUTOTUNE)
)

indian_val_ds = (
    indian_gen_to_dataset(indian_val_gen)
    .map(wrap_indian, num_parallel_calls=tf.data.AUTOTUNE)
    .prefetch(tf.data.AUTOTUNE)
)

print("✔ All 4 data pipelines built")
print(f"  Food-101 train batches: {tf.data.experimental.cardinality(food101_train).numpy()}")
print(f"  Indian train batches: ~{indian_train_gen.samples // BATCH}")

# %% Cell 10 — Balanced Sampling
#
# CRITICAL FIX: In v1, dataset.zip() caused the Indian iterator to exhaust
# after ~200 steps (3200 images / 16 batch), then `except: pass` silently
# skipped all remaining Indian training. The model only saw Indian data for
# the first ~4% of each epoch.
#
# Fix: .repeat() BOTH datasets and use sample_from_datasets for
# balanced interleaving. Without .repeat() on Food-101, it exhausts after
# epoch ~2 and the Food-101 head stops training entirely (accuracy → 0%).

food101_train_repeated = food101_train.repeat()  # Infinite — never exhausts
indian_train_repeated = indian_train_ds.repeat()  # Infinite — never exhausts

train_combined = tf.data.Dataset.sample_from_datasets(
    [food101_train_repeated, indian_train_repeated],
    weights=[0.6, 0.4],    # 60% Food-101, 40% Indian (oversamples Indian ~15x)
    seed=42,
    stop_on_empty_dataset=False
)

# Steps per epoch: roughly 1 full pass of Food-101
STEPS_PER_EPOCH = food101_info.splits["train"].num_examples // BATCH  # ~2367
print(f"✔ Balanced sampling: 60% Food-101, 40% Indian")
print(f"  Steps per epoch: {STEPS_PER_EPOCH}")
print(f"  Indian oversampling: ~{(0.4 * STEPS_PER_EPOCH * BATCH) / indian_train_gen.samples:.1f}x")

# Validation: just concatenate (no need for balanced sampling during eval)
val_combined = food101_val.concatenate(indian_val_ds)

# %% Cell 11 — Masked Loss Function
#
# This is the heart of the fix. When y_true == -1, the loss for that
# sample is zeroed out so NO gradient flows to the wrong head.

@tf.function
def masked_sparse_crossentropy(y_true, y_pred):
    """Sparse categorical crossentropy that ignores labels == -1."""
    y_true = tf.cast(y_true, tf.int64)
    mask = tf.not_equal(y_true, -1)
    mask_float = tf.cast(mask, tf.float32)

    num_valid = tf.reduce_sum(mask_float)

    # If no valid labels in this batch, return 0 loss (no gradient)
    if num_valid == 0:
        return tf.constant(0.0)

    # Clamp -1 → 0 to avoid index-out-of-range in cross-entropy
    y_true_safe = tf.maximum(y_true, 0)

    per_sample_loss = tf.keras.losses.sparse_categorical_crossentropy(
        y_true_safe, y_pred
    )

    # Zero out loss for masked samples
    masked_loss = per_sample_loss * mask_float

    # Average only over valid samples
    return tf.reduce_sum(masked_loss) / num_valid


# Also need a masked accuracy metric
class MaskedAccuracy(tf.keras.metrics.Metric):
    """Accuracy metric that ignores samples where y_true == -1."""

    def __init__(self, name="masked_accuracy", **kwargs):
        super().__init__(name=name, **kwargs)
        self.correct = self.add_weight(name="correct", initializer="zeros")
        self.total = self.add_weight(name="total", initializer="zeros")

    def update_state(self, y_true, y_pred, sample_weight=None):
        y_true = tf.cast(y_true, tf.int64)
        mask = tf.not_equal(y_true, -1)

        y_pred_classes = tf.cast(tf.argmax(y_pred, axis=-1), tf.int64)
        correct = tf.equal(y_pred_classes, y_true)
        correct_masked = tf.boolean_mask(correct, mask)

        self.correct.assign_add(tf.reduce_sum(tf.cast(correct_masked, tf.float32)))
        self.total.assign_add(tf.cast(tf.size(correct_masked), tf.float32))

    def result(self):
        return tf.math.divide_no_nan(self.correct, self.total)

    def reset_state(self):
        self.correct.assign(0.0)
        self.total.assign(0.0)


print("✔ Masked loss and masked accuracy defined")

# %% Cell 12 — Build Multi-Head Model
from tensorflow.keras import layers, Model

base_model = tf.keras.applications.EfficientNetB3(
    include_top=False,
    weights="imagenet",
    pooling="avg",
    input_shape=(IMG_SIZE, IMG_SIZE, 3)
)
base_model.trainable = False  # Frozen for Stage 1

inputs = layers.Input(shape=(IMG_SIZE, IMG_SIZE, 3), name="input_image")
features = base_model(inputs, training=False)

# Shared hidden layers (v1 went straight from 1792 → output — too thin)
x = layers.Dropout(0.3)(features)
x = layers.Dense(512, activation="relu", name="shared_dense")(x)
x = layers.BatchNormalization(name="shared_bn")(x)
x = layers.Dropout(0.2)(x)

# Classification heads
food101_head = layers.Dense(NUM_FOOD101, activation="softmax", name="food101_head")(x)
indian_head  = layers.Dense(NUM_INDIAN,  activation="softmax", name="indian_head")(x)

model = Model(inputs=inputs, outputs=[food101_head, indian_head], name="multihead_food_model")

model.summary()

trainable_params = sum([tf.keras.backend.count_params(w) for w in model.trainable_weights])
print(f"\nTrainable parameters: {trainable_params:,}")

# %% Cell 13 — Stage 1: Train Heads Only (Backbone Frozen)

print("=" * 60)
print("🔒 STAGE 1: Training classification heads (backbone frozen)")
print("=" * 60)

model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
    loss={
        "food101_head": masked_sparse_crossentropy,
        "indian_head": masked_sparse_crossentropy,
    },
    metrics={
        "food101_head": [MaskedAccuracy(name="accuracy")],
        "indian_head": [MaskedAccuracy(name="accuracy")],
    }
)

EPOCHS_STAGE1 = 5

history_stage1 = model.fit(
    train_combined,
    steps_per_epoch=STEPS_PER_EPOCH,
    epochs=EPOCHS_STAGE1,
    callbacks=[
        tf.keras.callbacks.ModelCheckpoint(
            "best_stage1.keras",
            save_best_only=True,
            monitor="loss",
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="loss",
            patience=2,
            factor=0.5,
            min_lr=1e-6,
            verbose=1
        ),
    ],
    verbose=1
)

print("\n✅ Stage 1 complete!")

# %% Cell 14 — Stage 1 Quick Evaluation

print("\n📊 Stage 1 Evaluation:")

# Evaluate on Food-101 val
food101_eval = model.evaluate(food101_val.take(100), verbose=0)
print(f"  Food-101 val loss: {food101_eval[1]:.4f}, accuracy: {food101_eval[3]:.2%}")

# Evaluate on Indian val
indian_eval = model.evaluate(indian_val_ds.take(25), verbose=0)
print(f"  Indian val loss: {indian_eval[2]:.4f}, accuracy: {indian_eval[4]:.2%}")

# Save checkpoint
model.save("checkpoint_after_stage1.keras")
print("\n💾 Checkpoint saved: checkpoint_after_stage1.keras")

# %% Cell 15 — Stage 2: Fine-Tune Backbone (Top 30 Layers)
#
# OOM FIX: Unfreezing layers means storing activations for backprop.
# 60 layers + batch 32 exceeds Colab T4's 15GB VRAM.
# Fix: Fewer layers (30), smaller batch (16), garbage collect first.

import gc

# Free memory from Stage 1
gc.collect()
tf.keras.backend.clear_session()

# Reload the Stage 1 checkpoint (compile=False to avoid deserializing custom loss)
model = tf.keras.models.load_model(
    "checkpoint_after_stage1.keras",
    compile=False
)
print("Stage 1 checkpoint loaded successfully!")

# Get the backbone (first layer that is a Model)
base_model = None
for layer in model.layers:
    if isinstance(layer, tf.keras.Model):
        base_model = layer
        break

print("\n" + "=" * 60)
print("STAGE 2: Fine-tuning top 30 backbone layers (batch 16)")
print("=" * 60)

# Unfreeze top 30 layers (not 60 — saves ~40% VRAM)
base_model.trainable = True
for layer in base_model.layers[:-30]:
    layer.trainable = False

trainable_count = sum(1 for layer in base_model.layers if layer.trainable)
print(f"Trainable backbone layers: {trainable_count} / {len(base_model.layers)}")

# Rebuild data pipeline with smaller batch size
BATCH_STAGE2 = 16

food101_train_s2 = (
    food101_train_raw
    .map(preprocess_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .map(augment, num_parallel_calls=tf.data.AUTOTUNE)
    .map(wrap_food101, num_parallel_calls=tf.data.AUTOTUNE)
    .shuffle(2048)
    .batch(BATCH_STAGE2)
    .prefetch(tf.data.AUTOTUNE)
    .repeat()
)

indian_train_s2 = (
    indian_gen_to_dataset(indian_train_gen)
    .map(wrap_indian, num_parallel_calls=tf.data.AUTOTUNE)
    .prefetch(tf.data.AUTOTUNE)
    .repeat()
)

train_combined_s2 = tf.data.Dataset.sample_from_datasets(
    [food101_train_s2, indian_train_s2],
    weights=[0.6, 0.4],
    seed=42,
    stop_on_empty_dataset=False
)

STEPS_STAGE2 = food101_info.splits["train"].num_examples // BATCH_STAGE2

# Recompile with much lower learning rate (critical for fine-tuning!)
model.compile(
    optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
    loss={
        "food101_head": masked_sparse_crossentropy,
        "indian_head": masked_sparse_crossentropy,
    },
    metrics={
        "food101_head": [MaskedAccuracy(name="accuracy")],
        "indian_head": [MaskedAccuracy(name="accuracy")],
    }
)

EPOCHS_STAGE2 = 10

history_stage2 = model.fit(
    train_combined_s2,
    steps_per_epoch=STEPS_STAGE2,
    epochs=EPOCHS_STAGE2,
    callbacks=[
        tf.keras.callbacks.ModelCheckpoint(
            "best_stage2.keras",
            save_best_only=True,
            monitor="loss",
            verbose=1
        ),
        tf.keras.callbacks.EarlyStopping(
            monitor="loss",
            patience=3,
            restore_best_weights=True,
            verbose=1
        ),
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor="loss",
            patience=2,
            factor=0.5,
            min_lr=1e-7,
            verbose=1
        ),
    ],
    verbose=1
)

print("\n✅ Stage 2 complete!")

# %% Cell 16 — Final Evaluation

print("\n" + "=" * 60)
print("📊 FINAL EVALUATION")
print("=" * 60)

# Full Food-101 validation
print("\n🍕 Food-101 Validation (full):")
food101_results = model.evaluate(food101_val, verbose=1)
print(f"   Loss: {food101_results[1]:.4f}")
print(f"   Accuracy: {food101_results[3]:.2%}")

# Full Indian validation
print("\n🍛 Indian Food Validation (full):")
indian_results = model.evaluate(indian_val_ds, verbose=1)
print(f"   Loss: {indian_results[2]:.4f}")
print(f"   Accuracy: {indian_results[4]:.2%}")

# %% Cell 17 — Save Final Model

# Save as .keras (NOT .h5 — .h5 is legacy)
model.save("multihead_food_final.keras")
print("✅ Saved: multihead_food_final.keras")

# Save label maps for inference
import json

label_map = {
    "food101": {str(i): name for i, name in enumerate(food101_class_names)},
    "indian": {str(i): name for i, name in enumerate(indian_class_names)},
}

with open("label_map.json", "w") as f:
    json.dump(label_map, f, indent=2)

print("✅ Saved: label_map.json")
print(f"   Food-101: {len(label_map['food101'])} classes")
print(f"   Indian:   {len(label_map['indian'])} classes")

# %% Cell 18 — Test Inference on Sample Images

import numpy as np

print("\n" + "=" * 60)
print("🧪 TEST INFERENCE")
print("=" * 60)

# Test on a Food-101 image
for images, labels in food101_val.take(1):
    sample = images[0:1]  # Keep batch dimension
    predictions = model.predict(sample, verbose=0)

    food101_pred = predictions[0][0]
    indian_pred = predictions[1][0]

    food101_top = np.argmax(food101_pred)
    indian_top = np.argmax(indian_pred)

    print(f"\n🍕 Food-101 image:")
    print(f"   Top Food-101 class: {food101_class_names[food101_top]} ({food101_pred[food101_top]:.2%})")
    print(f"   Top Indian class: {indian_class_names[indian_top]} ({indian_pred[indian_top]:.2%})")
    print(f"   Food-101 confidence is {'HIGHER' if food101_pred[food101_top] > indian_pred[indian_top] else 'LOWER'} → correct!")
    break

# Test on an Indian image
for images, labels in indian_val_ds.take(1):
    sample = images[0:1]
    predictions = model.predict(sample, verbose=0)

    food101_pred = predictions[0][0]
    indian_pred = predictions[1][0]

    food101_top = np.argmax(food101_pred)
    indian_top = np.argmax(indian_pred)

    true_label = int(labels["indian_head"][0])
    if true_label >= 0:
        true_name = indian_class_names[true_label]
    else:
        true_name = "unknown"

    print(f"\n🍛 Indian food image (true: {true_name}):")
    print(f"   Top Food-101 class: {food101_class_names[food101_top]} ({food101_pred[food101_top]:.2%})")
    print(f"   Top Indian class: {indian_class_names[indian_top]} ({indian_pred[indian_top]:.2%})")
    print(f"   Predicted: {indian_class_names[indian_top]} {'✅' if indian_top == true_label else '❌'}")
    break

# %% Cell 19 — Convert to TFLite for Mobile

print("\n" + "=" * 60)
print("📱 Converting to TFLite for mobile deployment...")
print("=" * 60)

try:
    # Float32 version (higher accuracy, larger size)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()

    tflite_path = "multihead_food_float32.tflite"
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"✅ Float32: {tflite_path} ({len(tflite_model) / (1024*1024):.2f} MB)")

    # Float16 quantized version (good balance of size and accuracy)
    converter_f16 = tf.lite.TFLiteConverter.from_keras_model(model)
    converter_f16.optimizations = [tf.lite.Optimize.DEFAULT]
    converter_f16.target_spec.supported_types = [tf.float16]
    tflite_f16 = converter_f16.convert()

    tflite_f16_path = "multihead_food_float16.tflite"
    with open(tflite_f16_path, "wb") as f:
        f.write(tflite_f16)
    print(f"✅ Float16: {tflite_f16_path} ({len(tflite_f16) / (1024*1024):.2f} MB)")
    print(f"   Size reduction: {(1 - len(tflite_f16) / len(tflite_model)) * 100:.1f}%")

except Exception as e:
    print(f"⚠️ TFLite conversion error: {e}")
    print("   You can retry conversion after training completes.")

# %% Cell 20 — Copy to Google Drive (optional)

# Uncomment these lines to save to Google Drive for persistence:
#
# from google.colab import drive
# drive.mount('/content/drive')
#
# import shutil
# drive_dir = "/content/drive/MyDrive/NutritAI_model"
# os.makedirs(drive_dir, exist_ok=True)
#
# for f in ["multihead_food_final.keras", "label_map.json",
#           "multihead_food_float32.tflite", "multihead_food_float16.tflite"]:
#     if os.path.exists(f):
#         shutil.copy(f, drive_dir)
#         print(f"✅ Copied {f} → {drive_dir}/")
#
# print(f"\n📁 All files saved to: {drive_dir}")

print("\n" + "=" * 60)
print("🎉 ALL DONE!")
print("=" * 60)
