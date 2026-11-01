import bpy

bpy.ops.wm.open_mainfile(filepath=r"C:\Users\Sylis\Desktop\player models\jax_UPDATE6_RELEASE.blend")
mat = bpy.data.materials.get("jax_normalMAT")
print("use_nodes", mat.use_nodes)
tree = mat.node_tree
for node in tree.nodes:
    inputs = []
    for sock in node.inputs:
        if sock.is_linked:
            link = sock.links[0]
            inputs.append(f"{sock.name}<-{link.from_node.name}.{link.from_socket.name}")
        elif hasattr(sock, "default_value") and not isinstance(sock.default_value, str):
            try:
                value = tuple(round(float(v), 2) for v in sock.default_value)
            except TypeError:
                value = sock.default_value
            inputs.append(f"{sock.name}={value}")
    extra = ""
    if node.type == "TEX_IMAGE" and node.image:
        extra = f" image={node.image.name} {node.image.size[0]}x{node.image.size[1]}"
    if node.type == "VERTEX_COLOR":
        extra = f" layer={node.layer_name}"
    print(node.name, node.type, extra)
    for item in inputs:
        print("   ", item)
