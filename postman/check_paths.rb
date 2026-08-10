require "json"
require "yaml"

spec = YAML.safe_load_file(File.expand_path("../swagger/satullia-api.yaml", __dir__), aliases: true)
valid = spec["paths"].keys
col = JSON.parse(File.read(File.expand_path("satullia.postman_collection.json", __dir__)))

KNOWN = ["/api/v1/definitely-not-a-service"]
regexes = valid.map do |t|
  re = t.split(/(\{[^}]+\})/).map { |s| s.start_with?("{") ? "[^/]+" : Regexp.escape(s) }.join
  Regexp.new("\\A" + re + "\\z")
end

bad = []
walk = lambda do |items|
  items.each do |i|
    if i["item"]
      walk.call(i["item"])
    elsif i["request"]
      raw = i.dig("request", "url", "raw").to_s
      path = raw.sub(%r|^\{\{[^}]+\}\}/|, "")
      path = path.sub(%r|^https?://[^/]+|, "")
      path = "/" + path unless path.start_with?("/")
      path = path.split("?").first
      bad << [raw, path] unless KNOWN.include?(path) || regexes.any? { |r| r =~ path }
    end
  end
end
walk.call(col["item"])

if bad.empty?
  puts "OK — every Postman request maps to a spec path template."
else
  bad.each { |r, p| puts "MISSING: #{r}  ->  #{p}" }
  exit 1
end