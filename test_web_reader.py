import sys
sys.path.insert(0, 'skills/web-reader')
from __init__ import web_reader

test_url = 'https://www.example.com'
result = web_reader(test_url)
print('Test result:', result[:200])
print('Length:', len(result))