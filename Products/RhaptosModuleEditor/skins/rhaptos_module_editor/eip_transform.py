## Script (Python) "eip_transform"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=content=None
##title=
from Products.RhaptosModuleEditor import MODULE_EIP_XSL
from Products.CNXMLDocument.XMLService import XMLError
from Products.CNXMLDocument import XMLService

request = context.REQUEST

versioninfo = context.rmeVersionInfo()
cnxmlvers = versioninfo['cnxmlvers'] or '0.7'
if content is None:
    try:
        content = request['BODY']
    except KeyError:
        raise TypeError, "No content provided"

results = XMLService.validate(content, url="http://cnx.rice.edu/technology/cnxml/schema/rng/%s/cnxml-fragment.rng" % cnxmlvers)

if results:
    request.RESPONSE.setStatus(400, "Invalid CNXML")
    return results

else:
    return context.cnxml_transform(content, stylesheet=MODULE_EIP_XSL)
