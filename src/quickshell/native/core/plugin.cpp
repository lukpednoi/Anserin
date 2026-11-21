// Registers the Anserin core types for QML (import "../native/core"; qmldir: module Anserin.Core).
#include <QQmlExtensionPlugin>
#include <qqml.h>

#include "sfx.h"

class AnserinCorePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<SfxEngine>(uri, 1, 0, "SfxEngine"); }
};

#include "plugin.moc"
