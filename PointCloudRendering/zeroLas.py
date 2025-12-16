import numpy as np
from plyfile import PlyData, PlyElement

ply = PlyData.read("PlotOfInterest.ply")
vertices = ply["vertex"]

pts = np.vstack([vertices["x"], vertices["y"], vertices["z"]]).T

min_vals = pts.min(axis=0)
max_vals = pts.max(axis=0)
center = (min_vals + max_vals) / 2

vertices["x"] = vertices["x"] - center[0]
vertices["y"] = vertices["y"] - center[1]
vertices["z"] = vertices["z"] - center[2]

PlyData([vertices]).write("centered_plot.ply")

print("Output saved to centered_output.ply")