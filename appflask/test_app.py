import unittest
from app import app  
import random
import string

class HelloNameTestCase(unittest.TestCase):
    def setUp(self):       
        self.app = app.test_client()
        self.app.testing = True

    def test_hello_name(self):       
        test_input = ''.join(random.choices(string.ascii_letters + ' ', k=12)).strip()  # יצירת טקסט דינמי
        response = self.app.get(f'/hello/{test_input}')
        self.assertEqual(response.status_code, 200)

        response_text = response.data.decode()
        for word in test_input.split():  # בדיקה שכל מילה מהקלט נמצאת בתשובה
            self.assertIn(word, response_text)

if _name_ == '_main_':
    unittest.main()