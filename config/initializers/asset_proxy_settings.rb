#
# Asset proxy settings
#
ActiveSupport.on_load(:active_record) do
  Banzai::Filter::AssetProxyFilter.initialize_settings
end
