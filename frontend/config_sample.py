# config.py
# User-editable configuration for Vivado paths and project directories

# Path to Vivado environment setup script (edit as needed)
VIVADO_SETTINGS_BAT = r"D:\Tools\Vivado\Vivado\2018.3\settings64.bat"

# Vivado binary name or path (edit as needed)
VIVADO_BIN = "vivado"

# Root directory for all backend projects (edit as needed)
BACKEND_ROOT = r"D:\RVCE\6th_Semester\IDP\Projects"

# Project-specific configuration
PROJECTS = {
    1: {
        "label": "Direct Mapped",
        "tcl": rf"{BACKEND_ROOT}\project_1\project_1.tcl",
        "output": rf"{BACKEND_ROOT}\project_1\project_1.sim\sim_1\behav\xsim\cache_metrics.txt"
    },
    2: {
        "label": "Direct Mapped Low Power",
        "tcl": rf"{BACKEND_ROOT}\project_2\project_2.tcl",
        "output": rf"{BACKEND_ROOT}\project_1\project_1.sim\sim_1\behav\xsim\cache_metrics.txt",
        "power1": rf"{BACKEND_ROOT}\precomp_metrics\power1.txt",
        "power2": rf"{BACKEND_ROOT}\precomp_metrics\power2.txt"
    },
    3: {
        "label": "Set Associative",
        "tcl": rf"{BACKEND_ROOT}\project_3\project_3.tcl",
        "output": rf"{BACKEND_ROOT}\project_3\project_3.sim\sim_1\behav\xsim\cache_metrics.txt"
    },
    4: {
        "label": "Combined Direct + Set Associative",
        "tcl": rf"{BACKEND_ROOT}\project_4\project_4.tcl",
        "output": rf"{BACKEND_ROOT}\project_4\project_4.sim\sim_1\behav\xsim\cache_metrics.txt"
    }
}
