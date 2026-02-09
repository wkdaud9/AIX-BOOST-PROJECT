importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBiOO61R_dO0ZepsfRdI0dTXmzO_Kzc_8Q",
  authDomain: "heybro-7ff89.firebaseapp.com",
  projectId: "heybro-7ff89",
  storageBucket: "heybro-7ff89.firebasestorage.app",
  messagingSenderId: "1039066889677",
  appId: "1:1039066889677:web:9ce48088471fa4e11f5884",
});

const messaging = firebase.messaging();

// 백그라운드 메시지 수신 처리
messaging.onBackgroundMessage((message) => {
  console.log("[FCM SW] 백그라운드 메시지:", message);
});
