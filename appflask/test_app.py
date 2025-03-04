import unittest
import sys
import os

sys.path.insert(0, "/app")

from app import app  

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
