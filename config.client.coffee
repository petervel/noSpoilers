Db = require 'db'
Obs = require 'obs'
Server = require 'server'
Form = require 'form'
Dom = require 'dom'
Ui = require 'ui'
App = require 'app'

exports.render = !->
	#if Db.shared
	#	Dom.div !-> "You can't change the tv show this app is showing. Start a new one for a different show."
	#	return

	cfg = Db.shared.get('cfg') || {}

	language = Obs.create()
	showName = Obs.create ''
	shows = Obs.create {}
	selectedShow = Obs.create()
	loading = Obs.create false

	findShow = !->
		return if not showName.peek().length
		loading.set true
		Server.call 'findShow', showName.peek(), language.peek(), (result) !->
			# TODO: shouldn't .set just clear existing values in this hash? else it'd be .merge right?
			shows.set {} # clear old search results
			shows.set result
			Obs.onTime 1000, !-> loading.set false # seems to be some delay??

	Form.box !->
		Dom.style width: '100%', boxSizing: 'border-box', border: '1px solid transparent'

		showId = Form.hidden 'showId'
		Obs.observe !-> showId.value selectedShow.get()

		Dom.div !->
			Obs.observe !->
				Dom.style display: if selectedShow.get() then 'none' else 'block'

			Form.segmented
				name: 'language'
				value: 'en'
				segments: ['en', 'English', 'nl', 'Dutch']
				onChange: (v) !->
					language.set v
					findShow()

			Obs.observe !->
				if showName.get().length
					Obs.onTime 500, !-> findShow()

			inp = Form.input
				name: '_showName'
				text: 'tv show'
				value: cfg.showName
				style: Flex: 1
				onChange: (val) !-> showName.set val

		Obs.observe !->
			if loading.get()
				Dom.div !->
					Dom.style fontStyle: 'italic', fontSize: '11pt', color: '#888'
					Dom.text "loading..."
				return

			return if not showName.get() # nothing searched

			empty = shows.count().get() is 0
			if not selectedShow.get()
				Dom.div !->
					Dom.style margin: '0 5px'
					if empty
						Dom.text "No matches found."
					else
						Dom.text "#{shows.count().get()} matches:"

			if not empty
				Dom.div !->
					Dom.style maxHeight: '300px', overflow: 'auto', border: '1px solid #eee', borderRadius: '3px'
					shows.iterate (show) !->
						Ui.item !->
							Dom.style position: 'relative'
							Obs.observe !->
								if sel = selectedShow.get()
									if sel is show.peek 'id'
										Dom.style border: "2px solid #{App.colors().highlight}", borderRadius: '3px'
									else
										Dom.style display: 'none'
								else
									Dom.style border: '2px solid transparent', display: 'block'
							Dom.div !->
								Dom.style
									position: 'absolute'
									zIndex: 1
									opacity: 0.1
									left: 0
									top: 0
									bottom: 0
									right: 0
									background: "transparent url(http://www.thetvdb.com/banners/#{show.get 'banner'}) no-repeat center"

							Dom.div !->
								Dom.style zIndex: 2
								Dom.div !->
									Dom.style fontWeight: 'bold', fontSize: '12pt', margin: '5px 0'
									Dom.text show.get 'seriesName'
								Dom.div !->
									Dom.style fontStyle: 'italic', color: '#aaa', fontSize: '10pt', maxHeight: '80px', overflow: 'hidden'
									Dom.text show.get 'overview'
							Dom.onTap !->
								if selectedShow.peek() isnt show.peek 'id'
									selectedShow.set show.peek 'id'
								else
									selectedShow.set null

		Form.condition !->
			return "No tv show selected" if not showId.value()

