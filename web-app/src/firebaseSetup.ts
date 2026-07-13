// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app" ;   

// TODO: Add SDKs for Firebase products that you want to use
// https://firebase.google.com/docs/web/setup#available-libraries

// Your web app's Firebase configuration
// For Firebase JS SDK v7.20.0 and later, measurementId is optional
const firebaseConfig = { 
  apiKey : "AIzaSyAq4PRFSBCAf3d_IfELk9dwPNlSjvSQ14M" , 
  authDomain : "carebike-app.firebaseapp.com" , 
  projectId : "carebike-app" , 
  storageBucket : "carebike-app.firebasestorage.app" , 
  messagingSenderId : "618141817330" , 
  appId : "1:618141817330:web:2f545cb93d1c7cfb5d736b" , 
  measurementId : "G-5TVPP5J0X5" 
};

// Initialize Firebase
initializeApp ( firebaseConfig );
