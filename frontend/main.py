import sys
import subprocess
import re
import os
import numpy as np
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QPushButton, QVBoxLayout, QRadioButton, QButtonGroup,
    QWidget, QLabel, QTabWidget
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QFont
from qt_material import apply_stylesheet
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

# Import global paths and project configs from config.py
from config import VIVADO_SETTINGS_BAT, VIVADO_BIN, PROJECTS, BACKEND_ROOT

def material_mpl_style():
    import matplotlib as mpl
    mpl.rcParams.update({
        "axes.facecolor": "#212121",
        "figure.facecolor": "#212121",
        "axes.edgecolor": "#ffffff",
        "axes.labelcolor": "#ffffff",
        "xtick.color": "#bdbdbd",
        "ytick.color": "#bdbdbd",
        "axes.grid": True,
        "grid.color": "#424242",
        "grid.linestyle": "--",
        "axes.titleweight": "bold",
        "axes.titlesize": 14,
        "axes.labelsize": 12,
        "legend.facecolor": "#263238",
        "legend.edgecolor": "#263238",
        "text.color": "#ffffff",
        "lines.linewidth": 2,
        "axes.prop_cycle": mpl.cycler(color=["#64b5f6", "#1976d2", "#ffd54f", "#ffb300", "#81c784", "#388e3c", "#e57373", "#d32f2f"]),
    })

def parse_file(filepath):
    times, hitcounts, misscounts, hitrates = [], [], [], []
    with open(filepath, 'r') as f:
        for line in f:
            m = re.search(
                r'Time:\s*(\d+).*?HitCount:\s*(\d+).*?MissCount:\s*(\d+).*?HitRate:\s*([\d\.]+)', line)
            if m:
                times.append(int(m.group(1)))
                hitcounts.append(int(m.group(2)))
                misscounts.append(int(m.group(3)))
                hitrates.append(float(m.group(4)))
    return times, hitcounts, misscounts, hitrates

def parse_project4_file(filepath):
    times, l1_hitrates, l2_hitrates = [], [], []
    with open(filepath, 'r') as f:
        for line in f:
            m = re.search(
                r'Time:\s*(\d+).*?L1_HitRate:\s*([\d\.]+).*?L2_HitRate:\s*([\d\.]+)', line)
            if m:
                times.append(int(m.group(1)))
                l1_hitrates.append(float(m.group(2)))
                l2_hitrates.append(float(m.group(3)))
    return times, l1_hitrates, l2_hitrates

def generate_tcl_file(project_id):
    """
    Generates a TCL file for Vivado simulation in the BACKEND_ROOT folder.
    Returns the path to the generated TCL file.
    """
    xpr_path = os.path.join(
        BACKEND_ROOT,
        f"project_{project_id}",
        f"project_{project_id}.xpr"
    )
    # Convert to double-backslash for TCL/Windows
    xpr_path_tcl = xpr_path.replace('\\', '\\\\')
    tcl_path = os.path.join(
        BACKEND_ROOT,
        f"auto_sim_project_{project_id}.tcl"
    )
    tcl_lines = [
        f'open_project "{xpr_path_tcl}"',
        'launch_simulation',
        'run 1ms',
        'close_sim',
        'exit'
    ]
    with open(tcl_path, 'w') as f:
        f.write('\n'.join(tcl_lines))
    return tcl_path

def run_vivado_and_sim(tcl_script_path):
    cmd = (
        "cmd.exe", "/c",
        f'call {VIVADO_SETTINGS_BAT} && {VIVADO_BIN} -mode batch -source {tcl_script_path}'
    )
    subprocess.run(cmd, shell=True)

def parse_power_table(filepath):
    groups = []
    with open(filepath, 'r') as f:
        lines = f.readlines()
    start = False
    for line in lines:
        if line.strip().startswith('Group'):
            start = True
            continue
        if start:
            if line.strip() == '' or line.startswith('---'):
                continue
            parts = line.split()
            if len(parts) >= 6 and parts[0] != "Total":
                groups.append({
                    'Group': parts[0],
                    'Internal': parts[1],
                    'Switching': parts[2],
                    'Leakage': parts[3],
                    'Total': parts[4],
                    'Percent': parts[5]
                })
    return groups

def plot_power_grouped_horizontal_bar(groups1, groups2):
    row_names = ["Sequential", "Combinational"]
    metrics = ["Internal", "Switching", "Leakage", "Total"]
    colors = [
        "#64b5f6", "#81c784",  # Internal Before, Internal After
        "#1976d2", "#388e3c",  # Switching Before, Switching After
        "#ffd54f", "#e57373",  # Leakage Before, Leakage After
        "#ffb300", "#d32f2f"   # Total Before, Total After
    ]
    legend_labels = [
        "Internal Before", "Internal After",
        "Switching Before", "Switching After",
        "Leakage Before", "Leakage After",
        "Total Before", "Total After"
    ]

    bar_values = []
    bar_colors = []
    y_labels = []

    g1_seq = next((g for g in groups1 if g['Group'] == "Sequential"), None)
    g2_seq = next((g for g in groups2 if g['Group'] == "Sequential"), None)
    for i, m in enumerate(metrics):
        bar_values.append(float(g1_seq[m]))
        bar_colors.append(colors[2*i])
        y_labels.append(f"Sequential {m} (Before)")
        bar_values.append(float(g2_seq[m]))
        bar_colors.append(colors[2*i+1])
        y_labels.append(f"Sequential {m} (After)")

    g1_comb = next((g for g in groups1 if g['Group'] == "Combinational"), None)
    g2_comb = next((g for g in groups2 if g['Group'] == "Combinational"), None)
    for i, m in enumerate(metrics):
        bar_values.append(float(g1_comb[m]))
        bar_colors.append(colors[2*i])
        y_labels.append(f"Combinational {m} (Before)")
        bar_values.append(float(g2_comb[m]))
        bar_colors.append(colors[2*i+1])
        y_labels.append(f"Combinational {m} (After)")

    bar_values.insert(8, 0)
    bar_colors.insert(8, "#212121")
    y_labels.insert(8, "")

    y_pos = np.arange(len(bar_values))

    fig = Figure(figsize=(10, 7))
    ax = fig.add_subplot(111)
    material_mpl_style()
    ax.barh(y_pos, bar_values, color=bar_colors, edgecolor='none', height=0.8)
    ax.set_yticks(y_pos)
    ax.set_yticklabels(y_labels, fontsize=11)
    ax.set_xlabel("Power (Watts)")
    ax.set_title("Power Metrics Comparison: Sequential and Combinational")

    custom_handles = []
    for i in range(0, 8, 2):
        h1 = ax.barh(-1, 0, color=colors[i])
        h2 = ax.barh(-1, 0, color=colors[i+1])
        custom_handles.append((h1[0], legend_labels[i]))
        custom_handles.append((h2[0], legend_labels[i+1]))
    ax.legend([h[0] for h in custom_handles], [h[1] for h in custom_handles], fontsize=10, loc='upper right', ncol=2)
    ax.grid(axis='x', linestyle='--', alpha=0.5)
    fig.tight_layout()
    fig.patch.set_facecolor("#212121")
    return FigureCanvas(fig)

class PlotCanvas(FigureCanvas):
    def __init__(self, parent=None, width=5, height=4, dpi=100):
        material_mpl_style()
        fig = Figure(figsize=(width, height), dpi=dpi)
        self.axes = fig.add_subplot(111)
        super().__init__(fig)

    def plot_hit_miss(self, times, hitcounts, misscounts):
        self.axes.clear()
        self.axes.plot(times, hitcounts, label='Hit Count', marker='o')
        self.axes.plot(times, misscounts, label='Miss Count', marker='o')
        self.axes.set_xlabel('Time (ps)')
        self.axes.set_ylabel('Count')
        self.axes.set_title('Hit Count and Miss Count vs Time')
        self.axes.legend()
        self.draw()

    def plot_hitrate(self, times, hitrates):
        self.axes.clear()
        self.axes.plot(times, hitrates, label='Hit Ratio', marker='o', color='#ffd54f')
        self.axes.set_xlabel('Time (ps)')
        self.axes.set_ylabel('Hit Ratio')
        self.axes.set_title('Hit Ratio vs Time')
        self.axes.legend()
        self.draw()

    def plot_l1_l2_hitrates(self, times, l1_hitrates, l2_hitrates):
        self.axes.clear()
        self.axes.plot(times, l1_hitrates, label='L1 Hit Rate', marker='o', color='#64b5f6')
        self.axes.plot(times, l2_hitrates, label='L2 Hit Rate', marker='s', color='#ffd54f')
        self.axes.set_xlabel('Time (ps)')
        self.axes.set_ylabel('Hit Rate')
        self.axes.set_title('L1 and L2 Hit Rate vs Time')
        self.axes.legend()
        self.draw()

class GraphWindow(QMainWindow):
    def __init__(self, output_file_path, project_id=None):
        super().__init__()
        self.setWindowTitle("Cache Simulation Results")
        self.setGeometry(100, 100, 950, 700)
        self.tabs = QTabWidget()
        self.tab1 = QWidget()
        self.tab2 = QWidget()

        if project_id == 4:
            self.times, self.l1_hitrates, self.l2_hitrates = parse_project4_file(output_file_path)
            self.canvas1 = PlotCanvas(self, width=8, height=5)
            self.canvas1.plot_l1_l2_hitrates(self.times, self.l1_hitrates, self.l2_hitrates)
            tab1_layout = QVBoxLayout()
            tab1_layout.addWidget(self.canvas1)
            self.tab1.setLayout(tab1_layout)
            self.tabs.addTab(self.tab1, "L1 & L2 Hit Rates")
        else:
            self.times, self.hitcounts, self.misscounts, self.hitrates = parse_file(output_file_path)
            self.canvas1 = PlotCanvas(self, width=8, height=5)
            self.canvas1.plot_hit_miss(self.times, self.hitcounts, self.misscounts)
            tab1_layout = QVBoxLayout()
            tab1_layout.addWidget(self.canvas1)
            self.tab1.setLayout(tab1_layout)
            self.canvas2 = PlotCanvas(self, width=8, height=5)
            self.canvas2.plot_hitrate(self.times, self.hitrates)
            tab2_layout = QVBoxLayout()
            tab2_layout.addWidget(self.canvas2)
            self.tab2.setLayout(tab2_layout)
            self.tabs.addTab(self.tab1, "Hits and Misses")
            self.tabs.addTab(self.tab2, "Hit Ratio")

        if project_id == 2:
            power_tab = QWidget()
            power_layout = QVBoxLayout()
            groups1 = parse_power_table(PROJECTS[2]['power1'])
            groups2 = parse_power_table(PROJECTS[2]['power2'])
            bar_canvas = plot_power_grouped_horizontal_bar(groups1, groups2)
            power_layout.addWidget(QLabel("Power Metrics Comparison (Before vs After Optimization)"))
            power_layout.addWidget(bar_canvas)
            power_tab.setLayout(power_layout)
            self.tabs.addTab(power_tab, "Power Metrics")

        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(32, 32, 32, 32)
        main_layout.addWidget(QLabel(f"Loaded: {output_file_path}"))
        main_layout.addWidget(self.tabs)
        container = QWidget()
        container.setLayout(main_layout)
        self.setCentralWidget(container)

class LauncherWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Verilog Cache Simulator")
        self.setGeometry(200, 200, 700, 250)
        main_layout = QVBoxLayout()
        main_layout.setContentsMargins(32, 32, 32, 32)

        header_label = QLabel("Verilog Cache Simulator")
        header_label.setStyleSheet("font-size: 28px; font-weight: bold; margin-bottom: 16px;")
        main_layout.addWidget(header_label, alignment=Qt.AlignmentFlag.AlignHCenter)

        cache_layout = QVBoxLayout()
        cache_label = QLabel("Cache Type")
        cache_label.setStyleSheet("font-size: 16px; font-weight: bold;")
        self.rb_direct = QRadioButton("Direct Mapped")
        self.rb_direct_lowpwr = QRadioButton("Direct Mapped Low Power")
        self.rb_setassoc = QRadioButton("Set Associative")
        self.rb_combined = QRadioButton("Combined Direct + Set Associative")
        self.rb_direct.setChecked(True)
        self.cache_group = QButtonGroup()
        self.cache_group.addButton(self.rb_direct, 1)
        self.cache_group.addButton(self.rb_direct_lowpwr, 2)
        self.cache_group.addButton(self.rb_setassoc, 3)
        self.cache_group.addButton(self.rb_combined, 4)
        cache_layout.addWidget(cache_label)
        cache_layout.addWidget(self.rb_direct)
        cache_layout.addWidget(self.rb_direct_lowpwr)
        cache_layout.addWidget(self.rb_setassoc)
        cache_layout.addWidget(self.rb_combined)
        cache_layout.addStretch()

        main_layout.addLayout(cache_layout)

        self.label = QLabel("Click to run Vivado simulation and show results.")
        self.button = QPushButton("Run Vivado Simulation")
        self.button.clicked.connect(self.run_and_show_graphs)
        main_layout.addWidget(self.label)
        main_layout.addWidget(self.button)

        central_widget = QWidget()
        central_widget.setLayout(main_layout)
        self.setCentralWidget(central_widget)

    def get_selected_project(self):
        if self.rb_direct.isChecked():
            return PROJECTS[1], 1
        elif self.rb_direct_lowpwr.isChecked():
            return PROJECTS[2], 2
        elif self.rb_setassoc.isChecked():
            return PROJECTS[3], 3
        elif self.rb_combined.isChecked():
            return PROJECTS[4], 4
        else:
            return PROJECTS[1], 1

    def run_and_show_graphs(self):
        project, pid = self.get_selected_project()
        self.label.setText(f"Generating TCL and running Vivado simulation for {project['label']}... Please wait.")
        QApplication.processEvents()
        tcl_path = generate_tcl_file(pid)
        run_vivado_and_sim(tcl_path)
        self.label.setText("Vivado simulation complete. Showing results...")
        QApplication.processEvents()
        self.graph_window = GraphWindow(project["output"], project_id=pid)
        self.graph_window.show()

if __name__ == '__main__':
    app = QApplication(sys.argv)
    apply_stylesheet(app, theme='dark_teal.xml')
    app.setFont(QFont("Segoe UI Variable Display"))
    window = LauncherWindow()
    window.show()
    sys.exit(app.exec())
