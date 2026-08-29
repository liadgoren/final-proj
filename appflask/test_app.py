import unittest
from app import app


class HelloNameTestCase(unittest.TestCase):
    def setUp(self):
        self.app = app.test_client()
        self.app.testing = True

    def test_hello_name(self):
        response = self.app.get('/hello/testuser')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Hello testuser!', response.data)

    def test_hello_name_escapes_html(self):
        response = self.app.get('/hello/%3Cimg%20src=x%3E')
        self.assertEqual(response.status_code, 200)
        self.assertNotIn(b'<img', response.data)
        self.assertIn(b'&lt;img', response.data)

    def test_hello_name_content_type_is_plain_text(self):
        response = self.app.get('/hello/testuser')
        self.assertTrue(response.content_type.startswith('text/plain'))

    def test_healthz(self):
        response = self.app.get('/healthz')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json(), {"status": "ok"})


if __name__ == '__main__':
    unittest.main()
