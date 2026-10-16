-- Kamera review "dermaga" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/dermaga.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/dermaga.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(40, 18, 85), Vector3.new(95, 4, 225))
print("[Kamera] dermaga siap")
