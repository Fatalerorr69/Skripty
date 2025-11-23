# Projekt: Chytrá meteorologická stanice
# Téma: Měření a vizualizace environmentálních dat
# Věková skupina: 15-18 let
# Doba trvání: 4-6 týdnů

from sense_hat import SenseHat
import matplotlib.pyplot as plt
import sqlite3
from datetime import datetime

class WeatherStation:
    def __init__(self):
        self.sense = SenseHat()
        self.db_connection = sqlite3.connect('weather_data.db')
        self.create_database()
    
    def create_database(self):
        # Vytvoření databáze pro ukládání naměřených dat
        cursor = self.db_connection.cursor()
        cursor.execute('''CREATE TABLE IF NOT EXISTS weather_data
                     (id INTEGER PRIMARY KEY AUTOINCREMENT,
                     timestamp DATETIME,
                     temperature REAL,
                     humidity REAL,
                     pressure REAL)''')
        self.db_connection.commit()
    
    def collect_data(self):
        # Sběr dat ze senzorů
        temperature = self.sense.get_temperature()
        humidity = self.sense.get_humidity()
        pressure = self.sense.get_pressure()
        
        # Uložení do databáze
        cursor = self.db_connection.cursor()
        cursor.execute("INSERT INTO weather_data (timestamp, temperature, humidity, pressure) VALUES (?, ?, ?, ?)",
                      (datetime.now(), temperature, humidity, pressure))
        self.db_connection.commit()
    
    def visualize_data(self):
        # Vizuualizace dat pomocí matplotlib
        cursor = self.db_connection.cursor()
        cursor.execute("SELECT timestamp, temperature, humidity, pressure FROM weather_data ORDER BY timestamp DESC LIMIT 100")
        data = cursor.fetchall()
        
        # Zpracování a vykreslení grafů
        timestamps = [row[0] for row in data]
        temperatures = [row[1] for row in data]
        
        plt.figure(figsize=(10, 6))
        plt.plot(timestamps, temperatures)
        plt.title('Teplotní trend')
        plt.xlabel('Čas')
        plt.ylabel('Teplota (°C)')
        plt.savefig('temperature_trend.png')
        plt.close()

# Hlavní programová smyčka
if __name__ == "__main__":
    station = WeatherStation()
    station.collect_data()
    station.visualize_data()