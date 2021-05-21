import xml.etree.ElementTree as ET

# Point this to the output of exportpicasa
XML_FILE_PATH = '/home/user/3/index.xml'

tree = ET.parse(XML_FILE_PATH)
root = tree.getroot()

for folder in root:
	folderName = folder.get('name')
	for file in folder:
		fileName = file.get('name')
		for face in file:
			personName = face.get('contact_name')
# Let digikam calculate these to train its AI
#			rectLeft = float(face.get('rect_left'))
#			rectRight = float(face.get('rect_right'))
#			rectTop = float(face.get('rect_top'))
#			rectBottom = float(face.get('rect_bottom'))
			if personName:
				print ('Image: ' + folderName + '/' + fileName + ', personName: ' + personName)

				print (rectLeft)

