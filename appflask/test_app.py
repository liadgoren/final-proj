import unittest
import sys
sys.path.append("/app")  # מוסיף את הנתיב של האפליקציה כדי שפייתון יוכל למצוא את app.py

from app import app  # הייבוא נשאר אותו הדבר

class HelloNameTestCase(unittest.TestCase):
    def setUp(self):       
        self.app = app.test_client()
        self.app.testing = True

    def test_hello_name(self):       
        response = self.app.get('/hello/testuser')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Hello testuser!', response.data)

if __name__ == '__main__':
    unittest.main()
