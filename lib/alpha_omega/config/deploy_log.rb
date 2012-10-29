Capistrano::Configuration.instance(:must_exist).load do |config|
  on :exit do
    unless ENV['LOCAL_ONLY'] && !ENV['LOCAL_ONLY'].empty?
      logger.important "uploading deploy logs: #{log_path}/#{application}-#{ENV["_AO_DEPLOYER"]}.log-#{Time.now.strftime('%Y%m%d-%H%M')}"
      put full_log, "#{log_path}/#{application}-#{ENV["_AO_DEPLOYER"]}.log-#{Time.now.strftime('%Y%m%d-%H%M')}"
    end
  end
end
