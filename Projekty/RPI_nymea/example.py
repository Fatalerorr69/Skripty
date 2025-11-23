# Ukázka vytvoření projektové šablony v Pythonu
from education_templates import ProjectTemplate

python_project = ProjectTemplate(
    name="Weather Station IoT",
    difficulty="beginner",
    subjects=["programming", "electronics", "data_science"],
    learning_objectives={
        "programming": "Python basics, API calls",
        "electronics": "Sensor connectivity",
        "data_science": "Data visualization"
    },
    estimated_duration="4 weeks",
    resources=["RPi 5", "BME280 sensor", "Python 3"]
)

python_project.save_template()