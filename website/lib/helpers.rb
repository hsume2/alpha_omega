def route_path(item)
  # in-memory items have not file
  return item.identifier + "index.html" if item[:content_filename].nil?

  url = item[:content_filename].gsub(/^content/, '')

  # determine output extension
  extname = '.' + item[:extension].split('.').last
  outext = '.haml'
  if url.match(/(\.[a-zA-Z0-9]+){2}$/) # => *.html.erb, *.html.md ...
    outext = '' # remove 2nd extension
  elsif extname == ".sass"
    outext = '.css'
  else
    outext = '.html'
  end
  url.gsub!(extname, outext)

  if url.include?('-')
    url = url.split('-').join('/')  # /2010/01/01-some_title.html -> /2010/01/01/some_title.html
  end

  url
end

