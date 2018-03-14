## Script (Python) "publishContent"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=message='', lens_paths=[], **kw
##title= Perform all content submission activities

versioninfo = context.rmeVersionInfo()
if context.publishBlocked(versioninfo):
    return state.set(status='failure', portal_status_message='publish blocked')
    
from Products.CMFCore.utils import getToolByName

portal = context.portal_url.getPortalObject()
repo = portal.content
newpublish = not(repo.hasRhaptosObject(context.objectId))

if context.state == 'pending' and context.portal_membership.getAuthenticatedMember().has_role('Manager'):
  context.set_publisher(users=[context.actor])  

# log a submit early so that logAction minimization stuff knows we're publishing
context.logAction('publish', message)

# move referenced work group/space file into the module ... on the down low
if context.portal_type == 'Module':
    uploadmsg = context.uploadWorkFiles()
else:
    uploadmsg = ''

# Remove any leftover completed collaboration requests
context.deleteCollaborationRequests()

# Remove CNXML upgrade working files
if hasattr(context,'excludedIds'):
    excluded = context.excludedIds()
    excludedexists = [n for n in excluded if getattr(context, n, None)]
    if excludedexists:
        context.manage_delObjects(excludedexists)

# Generate SVGs for MathML
import requests
from lxml import etree
# FIXME Hardcoded URL
url = "http://localhost:5689/"

file = context.getDefaultFile()
xml = etree.fromstring(file.getSource())
mathml_namespace = "http://www.w3.org/1998/Math/MathML"
mathml_blocks = xml.xpath(
    '//m:math[not(/m:annotation-xml[@encoding="image/svg+xml"])]',
    namespaces={'m': mathml_namespace})
for mathml_block in mathml_blocks:
    # Submit the MathML block to the SVG generation service.
    payload = {'MathML': etree.tostring(mathml_block)}
    response = requests.post(url, data=payload)
    # Inject the SVG into the MathML as an annotation
    # only if the resposne was good, otherwise skip over it.
    semantic_block = mathml_block.getchildren()[0]
    if response.status_code == 200:
        svg = response.text
        content_type = response.headers['content-type']
        # Insert the svg into the content
        annotation = etree.SubElement(
            semantic_block,
            '{%s}annotation-xml' % mathml_namespace)
        annotation.set('encoding', content_type)
        annotation.append(etree.fromstring(svg))
        file.setSource(etree.tostring(xml))
file.validate()

# publish/republish module
if newpublish:
    context.setBaseObject(repo.publishObject(context, message))
    context.aq_parent.manage_renameObjects([context.id], [context.objectId])
else:
    object = repo.getRhaptosObject(context.objectId)
    repo.publishRevision(context, message)

# remove Google Analytics Tracking Code from object
GoogleAnalyticsTrackingCode = None
if hasattr(context, 'GoogleAnalyticsTrackingCode'):
    GoogleAnalyticsTrackingCode = context.getGoogleAnalyticsTrackingCode()
    context.setGoogleAnalyticsTrackingCode(None)


# place Google Analytics Tracking Code into object's published folder
if GoogleAnalyticsTrackingCode is not None:
    versionFolder = repo.getRhaptosObject(context.objectId)
    versionFolder.setGoogleAnalyticsTrackingCode(GoogleAnalyticsTrackingCode)

# Now that we've committed, update the local metadata (version at least) from the repository 
context.updateMetadata()

# Remove all objects from content folder
# we want the logAction above, since delete doesn't trigger a logAction in 'published' state
context.manage_delObjects(context.objectIds())

# If the module was imported using SWORD, remove the additional attributes
if hasattr(context,'import_authors'):
  context.setImportAuthors([])

if hasattr(context,'is_imported'):
  context.setImported(False)

if hasattr(context,'has_attribution_note'):
  context.set_has_attribution_note(False)

# Update similarity  - temp remove this until we can reduce the load impact
# context.portal_similarity.storeSimilarity(context)

psm = context.translate("message_item_published", domain="rhaptos", default="Item Published.")
if uploadmsg: psm += '\n' + uploadmsg

try:
    if context.restrictedTraverse('@@siyavula')() and context.portal_type in ['Collection', 'Module']:
        # Switch the context        
        if context.portal_type == 'Module':
            return state.set(status='select_lens', portal_status_message=psm)
        elif context.portal_type == 'Collection':
            return state.set(status='select_col_lens', portal_status_message=psm)
except AttributeError:
    # If the Siyavula product isn't installed, silently fail
    pass

return state.set(status='success', portal_status_message=psm)
