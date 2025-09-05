import sys
import re
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QVBoxLayout, QWidget, QPushButton, QLabel
)
from matplotlib.backends.backend_qt5agg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure
from qt_material import apply_stylesheet

# Set your output file path here
OUTPUT_FILE_PATH = r"D:\\RVCE\\6th_Semester\\IDP\\Projects\\project_1\\project_1.sim\\sim_1\\behav\\xsim\\cache_metrics.txt"

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

class PlotCanvas(FigureCanvas):
    def __init__(self, parent=None, width=5, height=4, dpi=100):
        fig = Figure(figsize=(width, height), dpi=dpi)
        self.axes = fig.add_subplot(111)
        super().__init__(fig)

    def plot_hit_miss(self, times, hitcounts, misscounts):
        self.axes.clear()
        self.axes.plot(times, hitcounts, label='Hit Count', marker='o')
        self.axes.plot(times, misscounts, label='Miss Count', marker='o')
        self.axes.set_xlabel('Time')
        self.axes.set_ylabel('Count')
        self.axes.set_title('Hit Count and Miss Count vs Time')
        self.axes.legend()
        self.draw()

    def plot_hitrate(self, times, hitrates):
        self.axes.clear()
        self.axes.plot(times, hitrates, label='Hit Rate', marker='o', color='green')
        self.axes.set_xlabel('Time')
        self.axes.set_ylabel('Hit Rate')
        self.axes.set_title('Hit Rate vs Time')
        self.axes.legend()
        self.draw()

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Cache Simulation Results")
        self.setGeometry(100, 100, 800, 600)

        self.canvas = PlotCanvas(self, width=8, height=4)
        self.label = QLabel(f"Loaded: {OUTPUT_FILE_PATH}")
        self.btn_plot1 = QPushButton("Plot Hit/Miss Count")
        self.btn_plot2 = QPushButton("Plot Hit Rate")

        self.btn_plot1.clicked.connect(self.plot_hit_miss)
        self.btn_plot2.clicked.connect(self.plot_hitrate)

        layout = QVBoxLayout()
        layout.addWidget(self.label)
        layout.addWidget(self.btn_plot1)
        layout.addWidget(self.btn_plot2)
        layout.addWidget(self.canvas)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        # Load data on startup
        self.times, self.hitcounts, self.misscounts, self.hitrates = parse_file(OUTPUT_FILE_PATH)

    def plot_hit_miss(self):
        if self.times:
            self.canvas.plot_hit_miss(self.times, self.hitcounts, self.misscounts)

    def plot_hitrate(self):
        if self.times:
            self.canvas.plot_hitrate(self.times, self.hitrates)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    apply_stylesheet(app, theme='dark_teal.xml')  # Material Design theme
    window = MainWindow()
    window.show()
    sys.exit(app.exec())
