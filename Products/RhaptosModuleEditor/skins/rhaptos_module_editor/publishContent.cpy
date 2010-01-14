## Script (Python) "publishContent"
##bind container=container
##bind context=context
##bind namespace=
##bind script=script
##bind subpath=traverse_subpath
##parameters=message='', lens_paths=[], **kw
##title= Perform all content submission activities

from Products.CMFCore.utils import getToolByName

# log a submit early so that logAction minimization stuff knows we're publishing
newpublish = context.state == 'created'
context.logAction('submit', message)

# move referenced work group/space file into the module ... on the down low
if context.portal_type == 'Module':
    uploadmsg = context.uploadWorkFiles()
else:
    uploadmsg = ''

# Remove any leftover completed collaboration requests
context.deleteCollaborationRequests()

# Remove CNXML upgrade working files
bakname = 'index.cnxml.pre-v06', 'index.cnxml.pre-v07', 'index.cnxml.old'
bakexists = [n for n in bakname if getattr(context, n, None)]
if bakexists:
    context.manage_delObjects(bakexists)

# remove Google Analytics Tracking Code from object
GoogleAnalyticsTrackingCode = None
if hasattr(context, 'GoogleAnalyticsTrackingCode'):
    GoogleAnalyticsTrackingCode = context.getGoogleAnalyticsTrackingCode()
    context.setGoogleAnalyticsTrackingCode(None)

# publish/republish module
if newpublish:
    context.setBaseObject(context.content.publishObject(context, message))
    context.aq_parent.manage_renameObjects([context.id], [context.objectId])
else:
    object = context.content.getRhaptosObject(context.objectId)
    context.content.publishRevision(context, message)

# place Google Analytics Tracking Code into object's published folder
if GoogleAnalyticsTrackingCode is not None:
    versionFolder = context.content.getRhaptosObject(context.objectId)
    versionFolder.setGoogleAnalyticsTrackingCode(GoogleAnalyticsTrackingCode)

# Now that we've committed, update the local metadata (version at least) from the repository 
context.updateMetadata()

# Remove all objects from content folder
# we want the logAction above, since delete doesn't trigger a logAction in 'published' state
context.manage_delObjects(context.objectIds())

# Update similarity  - temp remove this until we can reduce the load impact
# context.portal_similarity.storeSimilarity(context)

psm = context.translate("message_item_published", domain="rhaptos", default="Item Published.")
if uploadmsg: psm += '\n' + uploadmsg

if context.restrictedTraverse('@@siyavula')() and context.portal_type in ['Collection', 'Module']:
    # Switch the context        
    if context.portal_type == 'Module':
        return state.set(status='select_lens', portal_status_message=psm)
    elif context.portal_type == 'Collection':
        return state.set(status='select_col_lens', portal_status_message=psm)

return state.set(status='success', portal_status_message=psm)