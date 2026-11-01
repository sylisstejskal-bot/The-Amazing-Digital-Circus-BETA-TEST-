import subprocess
from pathlib import Path

blender = r"C:\Users\Sylis\Desktop\_blender_app\blender-4.5.4-windows-x64\blender.exe"
script = r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\tools\export_faces.py"
src_root = Path(r"C:\Users\Sylis\Desktop\player models")
dst_root = Path(r"C:\Users\Sylis\Desktop\The Amazing Digital Circus\the-amazing-digital-circus\characters")
pairs = [
    ("jax_UPDATE6_RELEASE.blend", "jax.glb"),
    ("ragatha_UPDATE5_RELEASE.blend", "ragatha.glb"),
    ("caine_UPDATE5_RELEASE.blend", "caine.glb"),
    ("kinger_UPDATE5_RELEASE.blend", "kinger.glb"),
    ("zooble_UPDATE6_RELEASE.blend", "zooble.glb"),
    ("gangle_UPDATE5_RELEASE.blend", "gangle.glb"),
]
for src_name, dst_name in pairs:
    src = src_root / src_name
    dst = dst_root / dst_name
    print("RUN", src_name, flush=True)
    result = subprocess.run([blender, "--background", "--python", script, "--", str(src), str(dst)])
    print("EXIT", src_name, result.returncode, dst.stat().st_size if dst.exists() else 0, flush=True)
print("BATCH_DONE")
