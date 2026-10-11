# flutter_local_notifications serializes scheduled notifications with Gson.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# WorkManager (pulled in by the Google Mobile Ads SDK) creates its Room
# database by reflection (WorkDatabase_Impl). Without these rules R8 strips
# that class and the app crashes at launch in InitializationProvider.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
