import bpy, bmesh, csv, json, math, sys, os
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

argv = sys.argv[sys.argv.index('--') + 1:]
CSV, OUT = argv[0], argv[1]
MAXF = int(argv[2]) if len(argv) > 2 else 10**9
OUT = os.path.abspath(OUT)
os.makedirs(OUT, exist_ok=True)

rows = list(csv.DictReader(open(CSV)))
rows = [{k: float(v) for k, v in r.items()} for r in rows][:MAXF]

L1, R, PHIE, LC = 155.0, 9.5, math.radians(165), 5.0
RAMP_W, THK = 4.0, 0.55

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.render.image_settings.file_format = 'PNG'
try:
    sc.eevee.taa_render_samples = 24
except Exception:
    pass
sc.view_settings.view_transform = 'Standard'
sc.world = bpy.data.worlds.new('w')
sc.world.use_nodes = True
sc.world.node_tree.nodes['Background'].inputs[0].default_value = (0.004, 0.004, 0.006, 1)
sc.world.node_tree.nodes['Background'].inputs[1].default_value = 1.0


def mat(name, color, metallic=0.0, rough=0.5, emit=None, emit_strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = color
    b.inputs['Metallic'].default_value = metallic
    b.inputs['Roughness'].default_value = rough
    if emit is not None:
        b.inputs['Emission Color'].default_value = emit
        b.inputs['Emission Strength'].default_value = emit_strength
    if alpha < 1.0:
        b.inputs['Alpha'].default_value = alpha
        try:
            m.surface_render_method = 'BLENDED'
        except Exception:
            pass
    return m


def add(obj, material=None, parent=None):
    if material:
        obj.data.materials.append(material)
    if parent:
        obj.parent = parent
    return obj


def box(name, size, loc, material, parent=None, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        md = o.modifiers.new('b', 'BEVEL')
        md.width = bevel
        md.segments = 4
    bpy.ops.object.shade_smooth()
    return add(o, material, parent)


M_RED = mat('red', (0.55, 0.02, 0.02, 1), metallic=0.4, rough=0.25)
M_GLASS = mat('glass', (0.01, 0.01, 0.015, 1), metallic=0.0, rough=0.05)
M_TIRE = mat('tire', (0.02, 0.02, 0.02, 1), rough=0.8)
M_RIM = mat('rim', (0.7, 0.7, 0.72, 1), metallic=1.0, rough=0.25)
M_HEAD = mat('head', (1, 1, 1, 1), emit=(1, 1, 0.9, 1), emit_strength=20)
M_TAIL = mat('tail', (1, 0, 0, 1), emit=(1, 0.05, 0.05, 1), emit_strength=8)
M_GROUND = mat('ground', (0.07, 0.06, 0.055, 1), rough=0.85)
M_RAMP = mat('ramp', (0.55, 0.55, 0.56, 1), rough=0.45)
M_CONE = mat('cone', (1.0, 0.35, 0.0, 1), rough=0.5, emit=(1.0, 0.3, 0.0, 1), emit_strength=0.6)
M_PLUME = mat('plume', (1, 1, 1, 1), rough=1.0, emit=(1, 1, 1, 1), emit_strength=1.5, alpha=0.8)

# ground
bpy.ops.mesh.primitive_plane_add(size=1, location=(40, 0, -0.001))
g = bpy.context.object
g.scale = (400, 120, 1)
add(g, M_GROUND)

# ramp: ribbon following the path (arc up to PHIE, then a straight ceiling)
pts = []   # (x, z, nx, nz): path point and normal toward the loop centre
NA = 80
for i in range(NA + 1):
    ph = PHIE * i / NA
    pts.append((L1 + R * math.sin(ph), R * (1 - math.cos(ph)), -math.sin(ph), math.cos(ph)))
xe, ze = pts[-1][0], pts[-1][1]
for i in range(1, 11):
    d = LC * i / 10
    pts.append((xe + d * math.cos(PHIE), ze + d * math.sin(PHIE), -math.sin(PHIE), math.cos(PHIE)))
bm = bmesh.new()
inner_f = [bm.verts.new((x, -RAMP_W / 2, z)) for x, z, nx, nz in pts]
outer_f = [bm.verts.new((x - nx * THK, -RAMP_W / 2, z - nz * THK)) for x, z, nx, nz in pts]
inner_b = [bm.verts.new((x, RAMP_W / 2, z)) for x, z, nx, nz in pts]
outer_b = [bm.verts.new((x - nx * THK, RAMP_W / 2, z - nz * THK)) for x, z, nx, nz in pts]
n = len(pts)
for i in range(n - 1):
    bm.faces.new((inner_f[i], inner_f[i + 1], inner_b[i + 1], inner_b[i]))
    bm.faces.new((outer_f[i + 1], outer_f[i], outer_b[i], outer_b[i + 1]))
    bm.faces.new((inner_f[i + 1], inner_f[i], outer_f[i], outer_f[i + 1]))
    bm.faces.new((inner_b[i], inner_b[i + 1], outer_b[i + 1], outer_b[i]))
bm.faces.new((inner_f[0], inner_b[0], outer_b[0], outer_f[0]))
bm.faces.new((inner_b[-1], inner_f[-1], outer_f[-1], outer_b[-1]))
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
me = bpy.data.meshes.new('ramp')
bm.to_mesh(me)
bm.free()
ramp = bpy.data.objects.new('ramp', me)
sc.collection.objects.link(ramp)
for p in ramp.data.polygons:
    p.use_smooth = True
add(ramp, M_RAMP)
M_RAMP.node_tree.nodes['Principled BSDF'].inputs['Emission Color'].default_value = (0.9, 0.9, 0.95, 1)
M_RAMP.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value = 0.35

# cones (linked duplicates)
bpy.ops.mesh.primitive_cone_add(radius1=0.2, radius2=0.02, depth=0.5, location=(0, 0, 0.25), vertices=16)
cone0 = bpy.context.object
add(cone0, M_CONE)
for yy in (-3.2, -6.5, -10.5):
    for xx in range(-20, 260, 6):
        c = cone0.copy()
        c.location = (xx + (3 if yy == -6.5 else 0), yy, 0.25)
        sc.collection.objects.link(c)
for xx in range(-20, 260, 6):
    c = cone0.copy()
    c.location = (xx, 5.2, 0.25)
    sc.collection.objects.link(c)

# car
car = bpy.data.objects.new('car', None)
sc.collection.objects.link(car)
box('lower', (4.6, 1.95, 0.62), (0, 0, 0.62), M_RED, car, bevel=0.2)
box('hood', (1.4, 1.8, 0.18), (1.45, 0, 0.9), M_RED, car, bevel=0.07)
bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=32, ring_count=16, location=(-0.15, 0, 1.0))
cab = bpy.context.object
cab.scale = (1.25, 0.78, 0.42)
bpy.ops.object.shade_smooth()
add(cab, M_GLASS, car)
bpy.ops.mesh.primitive_uv_sphere_add(radius=1, segments=32, ring_count=16, location=(-0.2, 0, 1.2))
roof = bpy.context.object
roof.scale = (0.85, 0.74, 0.16)
bpy.ops.object.shade_smooth()
add(roof, M_RED, car)
box('spoiler', (0.35, 1.7, 0.06), (-2.2, 0, 1.0), M_RED, car, bevel=0.02)
for sy in (-0.7, 0.7):
    box('hl', (0.1, 0.4, 0.1), (2.25, sy, 0.7), M_HEAD, car, bevel=0.03)
    box('tl', (0.08, 0.5, 0.1), (-2.26, sy, 0.75), M_TAIL, car, bevel=0.02)
wheels, plumes = [], []
for wx in (1.35, -1.35):
    for wy in (-0.92, 0.92):
        e = bpy.data.objects.new('wh', None)
        sc.collection.objects.link(e)
        e.parent = car
        e.location = (wx, wy, 0.33)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.36, depth=0.28, vertices=32, rotation=(math.pi / 2, 0, 0))
        t = bpy.context.object
        bpy.ops.object.shade_smooth()
        add(t, M_TIRE, e)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.24, depth=0.3, vertices=32, rotation=(math.pi / 2, 0, 0))
        r = bpy.context.object
        bpy.ops.object.shade_smooth()
        add(r, M_RIM, e)
        for ang in (0, 60, 120):
            sp = box('sp', (0.5, 0.3, 0.05), (0, 0, 0), M_TIRE, e)
            sp.rotation_euler = (0, math.radians(ang), 0)
        wheels.append(e)
        bpy.ops.mesh.primitive_cone_add(radius1=0.16, radius2=0.3, depth=2.4, vertices=24,
                                        location=(wx, wy, 0.33 - 1.4))
        pl = bpy.context.object
        add(pl, M_PLUME, car)
        plumes.append(pl)

# headlight beam (soft translucent cone)
M_BEAM = mat('beam', (1, 1, 1, 1), emit=(1, 1, 1, 1), emit_strength=0.8, alpha=0.06)
bpy.ops.mesh.primitive_cone_add(radius1=0.05, radius2=0.9, depth=4.5, vertices=24)
beam = bpy.context.object
add(beam, M_BEAM, car)
beam.rotation_euler = (0, math.radians(90 + 6), 0)
beam.location = (2.3 + 2.2, 0, 0.5)

# lights
bpy.ops.object.light_add(type='SPOT', location=(0, 0, 0))
head = bpy.context.object
head.data.energy = 4000
head.data.spot_size = math.radians(40)
head.data.spot_blend = 0.6
head.data.shadow_soft_size = 0.2
head.parent = car
head.location = (2.2, 0, 0.75)
head.rotation_euler = (0, math.radians(90 + 8), 0)
bpy.ops.object.light_add(type='AREA')
key = bpy.context.object
key.data.energy = 2500
key.data.size = 14
bpy.ops.object.light_add(type='AREA')
fill = bpy.context.object
fill.data.energy = 2200
fill.data.size = 6
fill.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.light_add(type='SUN')
sun = bpy.context.object
sun.data.energy = 0.04
sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(20))

# camera
cam_d = bpy.data.cameras.new('cam')
cam_d.lens = 35
cam = bpy.data.objects.new('cam', cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)

arrows_all = []
cx = rows[0]['x']
cz = rows[0]['z'] + 1.3
for i, r in enumerate(rows):
    x, z, pitch = r['x'], r['z'], r['pitch_deg']
    mode = int(r['mode'])
    on_ramp = mode in (1, 4)
    ph = math.radians(pitch) if on_ramp else 0.0
    car.location = (x, 0, z)
    car.rotation_euler = (0, -math.radians(pitch), 0)
    for w in wheels:
        w.rotation_euler = (0, r['wheel_rad'], 0)
    for pl in plumes:
        pl.hide_render = (mode != 2) or r['thrust_g'] < 0.05
        pl.scale = (1, 1, 0.8 + 0.2 * math.sin(i * 1.7))
    key.location = (x, -2, z + 12)
    fill.location = (x, -9, z + 1.5)
    cx += (x - cx) * 0.7
    cz += ((z + 1.3) - cz) * 0.7
    cam.location = (cx, -17.5, cz)
    bpy.context.view_layer.update()
    sc.render.filepath = os.path.join(OUT, 'f%04d.png' % i)
    bpy.ops.render.render(write_still=True)

    # force arrows (1 m = 10 kN) in world coords
    nrm = Vector((-math.sin(ph), 0, math.cos(ph)))
    cg = Vector((x, 0, z + 0.6))
    fs = r['Fsuction_kN']
    mg = r['mg_kN']

    def px(v):
        co = world_to_camera_view(sc, cam, v)
        return [co.x * 1280, (1 - co.y) * 720]
    arr = []
    if mode in (0, 1, 3, 5) and (r['N_FL_kN'] + r['N_RL_kN']) > 0:
        for lx, Nk in ((1.35, r['N_FL_kN']), (-1.35, r['N_RL_kN'])):
            base = Vector((x + lx * math.cos(ph), 0, z + lx * math.sin(ph)))
            arr.append({'c': 'tire', 'a': px(base), 'b': px(base + nrm * Nk * 2 / 10.0)})
    arr.append({'c': 'grav', 'a': px(cg), 'b': px(cg + Vector((0, 0, -mg / 10.0)))})
    if fs > 0.1:
        arr.append({'c': 'suct', 'a': px(cg), 'b': px(cg - nrm * fs / 10.0)})
        tot = Vector((0, 0, -mg / 10.0)) - nrm * fs / 10.0
        arr.append({'c': 'sum', 'a': px(cg), 'b': px(cg + tot)})
    arrows_all.append(arr)

json.dump(arrows_all, open(os.path.join(OUT, 'arrows.json'), 'w'))
print('done', len(rows))
