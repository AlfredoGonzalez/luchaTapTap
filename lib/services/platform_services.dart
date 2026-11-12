// Picks the real ad and store services on Android and the fake ones in a
// browser (the GitHub Pages test build has no ads SDK or store).
export 'platform_services_stub.dart'
    if (dart.library.io) 'platform_services_io.dart';
