path = require "path"
fs = require "fs-extra"
glob = require "glob"
moment = require "moment"
eco = require "eco"
{toMarkdown} = require "to-markdown"

template = fs.readFileSync "#{__dirname}/post.yml.eco", "utf8"


input = path.join __dirname, "in"
output = path.join __dirname, "out"

fs.removeSync output
fs.mkdirSync output


files = glob.sync path.join input, "*.txt"
for file in files

	source = fs.readFileSync file, "utf8"
	continue unless source.length

	target = path.join output, path.basename file, ".txt"
	_posts = path.join target, "_posts"
	_drafts = path.join target, "_drafts"
	fs.mkdirsSync _posts
	fs.mkdirsSync _drafts

	posts = source.split "--------\n"
	for post in posts
		
		sections = post.split "-----\n"
		continue if sections.length < 3

		[properties, body] = sections

		meta = {}
		body = body.replace /BODY\:\n/, ""
		body = body.replace /(^\s+|\s+$)/, ""

		for property in properties.match /[A-Z ]+\: .+/g
			[name, rest...] = property.split ": "
			value = rest.join ": "

			addCategory = (method, category) ->
				meta.categories ?= []
				index = meta.categories.indexOf category
				meta.categories.splice index, 1 if index > -1
				meta.categories[method] category
			
			switch name
				when "AUTHOR"
					meta.author = value
				when "TITLE"
					meta.title = value
					meta.title.replace /"/g, "'"
				when "BASENAME"
					meta.slug = value.replace /_/g, "-"
				when "STATUS"
					meta.published = value is "Publish"
				when "DATE"
					meta.date = moment value, "MM/DD/YYYY hh:mm:ss A"
					meta.date_string = meta.date.format "YYYY-MM-DD HH:mm:ss"
				when "TAGS"
					meta.tags = value.match(/(["]?).*?\1(?=,|$)/g)
						.map((tag) -> tag.replace /^"(.*)"$/, "$1")
						.filter((tag) -> tag.length)
				when "PRIMARY CATEGORY"
					addCategory "unshift", value
				when "CATEGORY"
					addCategory "push", value

		markdown = toMarkdown body

		filename = path.join (if meta.published then _posts else _drafts), "#{meta.date.format "YYYY-MM-DD"}-#{meta.slug}.md"
		compiled = eco.render template, {meta, body, markdown}
		fs.writeFileSync filename, compiled


