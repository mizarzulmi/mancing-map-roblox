-- Kamera review "laguna" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/laguna.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/laguna.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(-140, 32, -40), Vector3.new(-250, 0, 40))
print("[Kamera] laguna siap")
