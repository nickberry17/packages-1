#
# Copyright (C) 2021
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=openwisp-monitoring
PKG_VERSION:=1
PKG_RELEASE:=1

PKG_MAINTAINER:=Nicholas Smith <nicholas.smith@telcoantennas.com.au>
PKG_LICENSE:=GPL-2.0

include $(INCLUDE_DIR)/package.mk

define Package/openwisp-monitoring
  SECTION:=admin
  CATEGORY:=Administration
  TITLE:=Support files for OpenWISP monitoring
  DEPENDS:=+openwisp-config netjson-monitoring
  PKGARCH:=all
endef

define Package/openwisp-monitoring/description
Support files for OpenWISP monitoring module.
endef

define Package/openwisp-monitoring/conffiles
/etc/config/openwisp-monitoring
endef

define Build/Compile
endef

define Package/openwisp-monitoring/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/openwisp-monitoring.init $(1)/etc/init.d/openwisp-monitoring
	$(INSTALL_DIR) $(1)/usr/sbin
	$(INSTALL_BIN) ./files/openwisp-monitoring.sh $(1)/usr/bin/openwisp-monitoring.sh
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/openwisp-monitoring.config $(1)/etc/config/openwisp-monitoring
endef

$(eval $(call BuildPackage,openwisp-monitoring))
