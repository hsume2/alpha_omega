<<HERE
git: git daemon --reuseaddr --base-path=. --export-all --verbose
deploy:   bundle exec cap deploy
major:    bundle exec cap deploy
patch:    bundle exec cap deploy
rollback: bundle exec cap deploy:rollback
stage:    bundle exec cap deploy:update_code
compare:  bundle exec cap deploy:compare
HERE
