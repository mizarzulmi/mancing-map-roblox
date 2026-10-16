-- Kamera review "udara" (Edit mode). Jalankan lalu screen_capture:
--   python scripts/studio_mcp.py luau scripts/camera/udara.luau --dm Edit
--   python scripts/studio_mcp.py call screen_capture "{}" --out build/captures/udara.png
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CFrame = CFrame.lookAt(Vector3.new(-260, 260, 520), Vector3.new(20, 0, 60))
print("[Kamera] udara siap")
