-- Kamera review "pasar" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/pasar.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/pasar.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(0, 22, -75), Vector3.new(0, 6, -5))
print("[Kamera] pasar siap")
