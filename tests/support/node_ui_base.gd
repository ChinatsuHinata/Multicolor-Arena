extends "res://tests/support/ui_base.gd"
func nodes_of_type(node,type):
 var out=[]
 if node.is_class(type):out.append(node)
 for child in node.get_children():out.append_array(nodes_of_type(child,type))
 return out
