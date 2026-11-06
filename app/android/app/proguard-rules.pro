# Room creates its generated database by reflection, through the no-argument
# constructor. The rule in Room's own library keeps the class but not that
# constructor, so R8 full mode strips it and marks the class abstract. WorkManager
# then fails to create WorkDatabase at process start, before any Flutter code
# runs, and every release build crashes on launch (decision #55).
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
