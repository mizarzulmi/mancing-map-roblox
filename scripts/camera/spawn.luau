-- Kamera review "spawn" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/spawn.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/spawn.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(0, 12, -52), Vector3.new(30, 4, 120))
print("[Kamera] spawn siap")
