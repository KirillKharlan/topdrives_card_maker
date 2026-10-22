"""Run in CI right after `flutter create`: adjusts the generated Android project.

- INTERNET: the update check talks to the GitHub API (release builds do not
  have this permission by default).
- WRITE_EXTERNAL_STORAGE (API <= 29): saving PNGs to the gallery on old Android.
- Human-readable app name.
"""
import pathlib
import re

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
text = manifest.read_text(encoding="utf-8")

permissions = [
    ("android.permission.INTERNET", '<uses-permission android:name="android.permission.INTERNET"/>'),
    (
        "android.permission.WRITE_EXTERNAL_STORAGE",
        '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29"/>',
    ),
]
block = "".join(f"    {tag}\n" for name, tag in permissions if name not in text)
if block:
    index = text.index("<application")
    text = text[:index] + block.lstrip() + "    " + text[index:]

text = re.sub(r'android:label="[^"]*"', 'android:label="Card Maker"', text, count=1)

manifest.write_text(text, encoding="utf-8")
print("AndroidManifest.xml patched")
