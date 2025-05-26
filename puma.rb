workers Integer(ENV['WEB_CONCURRENCY'] || 4)
threads_count = Integer(ENV['MAX_THREADS'] || 16)
threads threads_count, threads_count

preload_app!

port ENV.fetch('PORT') { 3000 }
environment ENV.fetch('RACK_ENV') { 'production' }

# No longer need worker boot hook for fast implementation

lowlevel_error_handler do |e|
  [500, {}, ["Internal Server Error"]]
end