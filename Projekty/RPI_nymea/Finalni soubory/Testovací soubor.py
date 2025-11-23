#!/usr/bin/env python3
"""
Testovací skript pro meteorologickou stanici
"""

import unittest
import sqlite3
import os
from unittest.mock import patch, MagicMock
from src.main import WeatherStation

class TestWeatherStation(unittest.TestCase):
    
    def setUp(self):
        """Příprava testovacího prostředí"""
        self.test_db_path = "/tmp/test_weather.db"
        self.station = WeatherStation()
        
        # Přepsání cesty k databázi pro testování
        self.station.conn = sqlite3.connect(self.test_db_path)
        self.station.cursor = self.station.conn.cursor()
        self.station.cursor.execute('''
            CREATE TABLE IF NOT EXISTS weather_data (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME,
                temperature REAL,
                humidity REAL,
                pressure REAL
            )
        ''')
        self.station.conn.commit()
    
    def tearDown(self):
        """Úklid testovacího prostředí"""
        if os.path.exists(self.test_db_path):
            os.remove(self.test_db_path)
    
    @patch('smbus2.SMBus')
    @patch('bme280.load_calibration_params')
    @patch('bme280.sample')
    def test_read_sensor_data(self, mock_sample, mock_calibration, mock_bus):
        """Test čtení dat ze senzoru"""
        # Nastavení mocků
        mock_sample.return_value = MagicMock()
        mock_sample.return_value.temperature = 25.5
        mock_sample.return_value.humidity = 60.0
        mock_sample.return_value.pressure = 1013.25
        
        # Testování
        data = self.station.read_sensor_data()
        
        self.assertIsNotNone(data)
        self.assertEqual(data['temperature'], 25.5)
        self.assertEqual(data['humidity'], 60.0)
        self.assertEqual(data['pressure'], 1013.25)
    
    def test_save_to_database(self):
        """Test ukládání dat do databáze"""
        test_data = {
            'temperature': 22.5,
            'humidity': 55.0,
            'pressure': 1005.0
        }
        
        # Uložení testovacích dat
        self.station.save_to_database(test_data)
        
        # Ověření, že data byla uložena
        self.station.cursor.execute("SELECT COUNT(*) FROM weather_data")
        count = self.station.cursor.fetchone()[0]
        self.assertEqual(count, 1)
        
        # Ověření hodnot
        self.station.cursor.execute("SELECT temperature, humidity, pressure FROM weather_data")
        row = self.station.cursor.fetchone()
        self.assertEqual(row[0], 22.5)
        self.assertEqual(row[1], 55.0)
        self.assertEqual(row[2], 1005.0)

if __name__ == '__main__':
    unittest.main()