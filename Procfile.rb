<<HERE
git: git daemon --reuseaddr --base-path=. --export-all --verbose
deploy:   bundle exec cap #{(options[:args]||[]).join(" ")} deploy
major:    bundle exec cap #{(options[:args]||[]).join(" ")} deploy
patch:    bundle exec cap #{(options[:args]||[]).join(" ")} deploy
rollback: bundle exec cap #{(options[:args]||[]).join(" ")} deploy:rollback
stage:    bundle exec cap #{(options[:args]||[]).join(" ")} deploy:update_code
compare:  bundle exec cap #{(options[:args]||[]).join(" ")} deploy:compare
shell:    bundle exec cap #{(options[:args]||[]).join(" ")} shell
HERE

