Comments = require 'comments'
Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
App = require 'app'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'


exports.render = !->
	if episodeId = Page.state.get(0)
		#if episodeId is 'add'
		#	renderAdd()
		#else
		renderEpisode episodeId
	else
		renderMainPage()

renderMainPage = !->
	Dom.h1 !->
		Dom.text 'Game of Thrones' #TODO replace with GoT.png

	Db.shared.iterate 'episodes', (episode) !->
		Ui.item !->
			Dom.onTap !->
				goToEpisode = !-> Page.nav episode.key()
				if episode.get 'seen', App.userId()
					goToEpisode()
				else
					Modal.confirm "Please confirm", "Are you sure you have already seen this episode?", !->
						Server.sync 'seen', episode.key(), !->
							episode.set 'seen', App.userId(), true
						goToEpisode()
			Dom.style Box: 'horizontal', alignItems: 'center'
			Dom.div !->
				Dom.style minWidth: '20px', textAlign: 'right', marginRight: '10px'
				Dom.text episode.key() + '.'
			Dom.div !->
				Dom.style Flex: 1
				Dom.text episode.get 'title'

			Dom.div !->
				Event.renderBubble [episode.key()]

	#The first one.. With the thing.
	#Ui.button "Add episode", !->
	#	Page.nav 'add'

renderEpisode = (id) !->
	episode = Db.shared.ref 'episodes', id

	Page.setTitle episode.get 'title'

	Dom.h1 !->
		Dom.style textAlign: 'center'
		Dom.text episode.get 'title'

	if episode.get 'image'
		Dom.img !->
			Dom.style margin: 'auto', display: 'block'
			Dom.prop 'src', episode.get 'image'

	if episode.get 'summary'
		Ui.card !->
			Dom.text episode.get 'summary'

	Comments.enable
		store: ['episodes', id, 'comments']

#renderAdd = !->
#	Page.setTitle "Add episode"
#	Ui.card !->
#		titleField = Form.input {text: 'Enter episode title.'}
#		Ui.button "Send", !->
#			if title = titleField.value()
#				Server.sync 'add', title, !->
#					Db.shared.set 'episodes', (Db.shared.peek 'maxId'), {title: title}
#				Page.nav ''