#!/bin/bash

# Check arguments
if [ $# -ne 1 ];
then
   echo "Usage:"
   echo "./Resign.sh <BundleIdentifier>"
   echo "Example:"
   echo "./Resign.sh com.niclet.yihome"
   exit 0
fi

# Create temp folder
TMP=`mktemp -d`

# Look for the certificate which lets sign provided bundle identifier
for CERTIFICATE in ~/Library/MobileDevice/Provisioning\ Profiles/*
do
   security cms -D -i "$CERTIFICATE" -o "$TMP/certificate.plist"
   if [ $? -eq 0 ];
   then
      NAME=`/usr/libexec/PlistBuddy -c "print :Name" "$TMP/certificate.plist"`
      if [ "$NAME" = "iOS Team Provisioning Profile: $1" ];
      then
         # Get TeamIdentifier to modify archived-expanded-entitlements.xcent
         TEAM_IDENTIFIER=`/usr/libexec/PlistBuddy -c "print :TeamIdentifier:0" "$TMP/certificate.plist"`
         # Get SHA1 Fingerprint used by codesign
         SHA1_FINGERPRINT=`/usr/libexec/PlistBuddy -c "print :DeveloperCertificates:0" "$TMP/certificate.plist" | openssl x509 -sha1 -inform der -noout -fingerprint`
         # Format is "SHA1 Fingerprint=XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
         # Remove "SHA1 Fingerprint="
         SHA1_FINGERPRINT=${SHA1_FINGERPRINT:17}
         # Remove all : characters
         SHA1_FINGERPRINT=${SHA1_FINGERPRINT//:/}
         # Patch Info.plist with new BundleIdentifier
         /usr/libexec/PlistBuddy -c "set CFBundleIdentifier $1" ./yihome_2_5_0/Payload/YiHome2.0.app/Info.plist
         # Patch archived-expanded-entitlements.xcent with new TeamIdenfitier
         /usr/libexec/PlistBuddy -c "set application-identifier $TEAM_IDENTIFIER.$1" ./yihome_2_5_0/Payload/YiHome2.0.app/archived-expanded-entitlements.xcent
         /usr/libexec/PlistBuddy -c "set keychain-access-groups:0 $TEAM_IDENTIFIER.$1" ./yihome_2_5_0/Payload/YiHome2.0.app/archived-expanded-entitlements.xcent
         # Resign application
         /usr/bin/codesign --force --sign $SHA1_FINGERPRINT --entitlements ./yihome_2_5_0/Payload/YiHome2.0.app/archived-expanded-entitlements.xcent --timestamp=none ./yihome_2_5_0/Payload/YiHome2.0.app
         # Done :)
         echo "Resigning is finished, you can now push yihome_2_5_0/Payload/YiHome2.0.app to your device from XCode/Devices management tool"
         exit
      fi
   fi
done

# Here, we didn't find something useful...
echo "Error: didn't find any provisioning profile matching given BundleIdentifier"
