#!/usr/bin/ruby
# frozen_string_literal: true

# Gross, but we need to make sure the SSG is updated before
# we build the source.
`gem update sawsge`

require 'English'
require 'fileutils'
require 'sawsge'
require 'git'

# Order of these arguments is hardcoded based on webhook
# configuration
REPO_NAME = ARGV[0]
GITHUB_USER = ARGV[1]
REPO_SSH_URL = ARGV[2]

ADMIN_HOME_DIR = '/home/admin'
WEBSITE_SRC_DIR = File.join(ADMIN_HOME_DIR, 'src')
REPO_SRC_DIR = File.join(WEBSITE_SRC_DIR, REPO_NAME)
GITHUB_PRIV_KEY = File.join(ADMIN_HOME_DIR, '.ssh/github')
SAWSGE_OUT_DIR = File.join(REPO_SRC_DIR, 'out/')
WEBSERVER_DIRECTORY = File.join(ADMIN_HOME_DIR, REPO_NAME)

BIN_DEPENDENCIES = %w[pandoc rsync git].freeze

def command?(bin)
  `which #{bin}`
  $CHILD_STATUS.success?
end

missing_dependencies = BIN_DEPENDENCIES.reject { |dep| command?(dep) }
abort "Missing dependencies: #{missing_dependencies}" unless missing_dependencies.empty?

ENV['GIT_SSH_COMMAND'] = "ssh -i #{GITHUB_PRIV_KEY}"

repo = if File.directory?(REPO_SRC_DIR)
         Git.open(REPO_SRC_DIR)
       else
         warn 'Cloning repository...'
         Git.clone(REPO_SSH_URL, REPO_SRC_DIR)
       end
warn 'Pulling new changes...'
repo&.pull

warn 'Building source...'
Sawsge.new(REPO_SRC_DIR).build

warn 'Syncing files...'
`rsync -au --delete '#{SAWSGE_OUT_DIR}' '#{WEBSERVER_DIRECTORY}'`

warn 'Done!'
