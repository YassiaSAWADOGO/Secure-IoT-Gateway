GATEWAYD_VERSION = 0.1
GATEWAYD_SITE = $(BR2_EXTERNAL_GATEWAY_PATH)/src/gatewayd
GATEWAYD_SITE_METHOD = local
GATEWAYD_LICENSE = MIT
GATEWAYD_USERS = gatewayd -1 gatewayd -1 * - - - Secure IoT gateway daemon

define GATEWAYD_BUILD_CMDS
	$(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D)
endef

define GATEWAYD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/gatewayd $(TARGET_DIR)/usr/sbin/gatewayd
endef

define GATEWAYD_INSTALL_INIT_SYSV
	$(INSTALL) -D -m 0755 $(GATEWAYD_PKGDIR)/S90gatewayd $(TARGET_DIR)/etc/init.d/S90gatewayd
endef

$(eval $(generic-package))
