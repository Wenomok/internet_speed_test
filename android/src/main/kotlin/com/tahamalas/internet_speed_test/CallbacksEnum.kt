package com.tahamalas.internet_speed_test


enum class CallbacksEnum {
    START_DOWNLOAD_TESTING,
    START_UPLOAD_TESTING,
    STOP_DOWNLOAD_TEST,
    STOP_UPLOAD_TEST
}

enum class ListenerEnum {
    COMPLETE,
    ERROR,
    PROGRESS
}