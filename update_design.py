import re

file_path = 'lib/screens/chat_screen.dart'

with open(file_path, 'r') as f:
    content = f.read()

properties_to_replace = [
    'primary', 'primarySoft', 'secondary', 'surface', 'background',
    'backgroundEnd', 'textPrimary', 'textSecondary', 'textTertiary',
    'border', 'inputBg', 'error', 'errorDark', 'success', 'dotLight',
    'primaryGradient', 'bgGradient', 'drawerGradient',
    'shadowPrimary', 'shadowError'
]

for prop in properties_to_replace:
    pattern = r'_Design\.' + prop + r'\b'
    replacement = r'_Design(context).' + prop
    content = re.sub(pattern, replacement, content)

with open(file_path, 'w') as f:
    f.write(content)

print("Done replacing.")
