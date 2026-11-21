enum AssessmentLanguage { english, hindi, hinglish }

extension AssessmentLanguageExtension on AssessmentLanguage {
  String get displayName {
    switch (this) {
      case AssessmentLanguage.english:
        return 'English';
      case AssessmentLanguage.hindi:
        return 'हिंदी';
      case AssessmentLanguage.hinglish:
        return 'Hinglish';
    }
  }

  String get nativeSubtitle {
    switch (this) {
      case AssessmentLanguage.english:
        return 'Standard Clinical & Medical Terms';
      case AssessmentLanguage.hindi:
        return 'सरल और स्पष्ट हिंदी अनुवाद';
      case AssessmentLanguage.hinglish:
        return 'Aasan Hinglish (Conversational)';
    }
  }

  String get flagEmoji {
    switch (this) {
      case AssessmentLanguage.english:
        return '🇬🇧';
      case AssessmentLanguage.hindi:
        return '🇮🇳';
      case AssessmentLanguage.hinglish:
        return '🇮🇳';
    }
  }
}

/// Comprehensive localization engine and dictionary for the Dr. Hair Assessment Report.
/// Supports English, Hindi, and Hinglish for all static and dynamic assessment terms.
class AssessmentTranslations {
  static const Map<String, Map<AssessmentLanguage, String>> _strings = {
    // Navigation / Header
    'assessment_report_title': {
      AssessmentLanguage.english: 'Assessment Report',
      AssessmentLanguage.hindi: 'हेयर असेसमेंट रिपोर्ट',
      AssessmentLanguage.hinglish: 'Assessment Report',
    },
    'retest': {
      AssessmentLanguage.english: 'Retest',
      AssessmentLanguage.hindi: 'पुनः जाँच',
      AssessmentLanguage.hinglish: 'Retest Karein',
    },

    // Review Notice & Timeline
    'clinical_review_completed': {
      AssessmentLanguage.english: 'Clinical Review Completed',
      AssessmentLanguage.hindi: 'चिकित्सीय समीक्षा पूर्ण',
      AssessmentLanguage.hinglish: 'Doctor Review Complete Ho Gaya Hai',
    },
    'clinical_review_is_complete': {
      AssessmentLanguage.english: 'Clinical review is complete',
      AssessmentLanguage.hindi: 'क्लिनिकल समीक्षा पूरी हो चुकी है',
      AssessmentLanguage.hinglish: 'Doctor review complete ho chuka hai',
    },
    'reviewed_by': {
      AssessmentLanguage.english: 'Reviewed by',
      AssessmentLanguage.hindi: 'समीक्षक',
      AssessmentLanguage.hinglish: 'Review kiya gaya:',
    },
    'care_plan_added': {
      AssessmentLanguage.english:
          'A clinician care plan has been added to this assessment.',
      AssessmentLanguage.hindi:
          'इस रिपोर्ट में डॉक्टर द्वारा व्यक्तिगत उपचार योजना जोड़ दी गई है।',
      AssessmentLanguage.hinglish: 'Aapke assessment ke liye doctor ka personalized care plan add kar diya gaya hai.',
    },
    'clinical_review_recorded': {
      AssessmentLanguage.english:
          'A clinical review has been recorded for this assessment.',
      AssessmentLanguage.hindi:
          'इस जाँच के लिए क्लिनिकल समीक्षा दर्ज कर ली गई है।',
      AssessmentLanguage.hinglish:
          'Is assessment ke liye clinical review note kar liya gaya hai.',
    },
    'scalp_photos_under_review': {
      AssessmentLanguage.english: 'Scalp Photos Under Review',
      AssessmentLanguage.hindi: 'स्कैल्प फ़ोटो समीक्षा में हैं',
      AssessmentLanguage.hinglish: 'Scalp Photos Review Ho Rahi Hain',
    },
    'clinical_review_in_progress': {
      AssessmentLanguage.english: 'Clinical review in progress',
      AssessmentLanguage.hindi: 'क्लिनिकल समीक्षा जारी है',
      AssessmentLanguage.hinglish: 'Doctor review abhi chal raha hai',
    },
    'photos_under_review_desc': {
      AssessmentLanguage.english: 'Your assessment is with the clinical team. We will show their review here when it is ready.',
      AssessmentLanguage.hindi:
          'आपकी रिपोर्ट क्लिनिकल टीम के पास है। तैयार होने पर यहाँ दिखेगी।',
      AssessmentLanguage.hinglish: 'Aapki report clinical team ke paas hai. Doctor review ready hote hi yahan dikh jayegi.',
    },
    'assessment_submitted': {
      AssessmentLanguage.english: 'Assessment Submitted',
      AssessmentLanguage.hindi: 'जाँच जमा की गई',
      AssessmentLanguage.hinglish: 'Assessment Submit Ho Chuka Hai',
    },
    'assessment_ready': {
      AssessmentLanguage.english: 'Your assessment is ready',
      AssessmentLanguage.hindi: 'आपकी रिपोर्ट तैयार है',
      AssessmentLanguage.hinglish: 'Aapki assessment report ready hai',
    },
    'clinician_review_needed_desc': {
      AssessmentLanguage.english:
          'A clinician review is needed before care suggestions are shown.',
      AssessmentLanguage.hindi:
          'देखभाल के सुझाव देखने से पहले डॉक्टर की समीक्षा आवश्यक है।',
      AssessmentLanguage.hinglish:
          'Care suggestions dekhne ke liye pehle doctor ka review zaroori hai.',
    },
    'assessment_summary_ready_desc': {
      AssessmentLanguage.english:
          'Your assessment summary and available next steps are shown below.',
      AssessmentLanguage.hindi:
          'आपकी रिपोर्ट का सारांश और उपलब्ध अगले कदम नीचे दिए गए हैं।',
      AssessmentLanguage.hinglish: 'Aapka assessment summary aur aage ke available steps neeche diye gaye hain.',
    },

    // Timeline Steps
    'intake_sent': {
      AssessmentLanguage.english: 'Intake Sent',
      AssessmentLanguage.hindi: 'जानकारी भेजी गई',
      AssessmentLanguage.hinglish: 'Intake Sent',
    },
    'doctor_review': {
      AssessmentLanguage.english: 'Doctor Review',
      AssessmentLanguage.hindi: 'डॉक्टर समीक्षा',
      AssessmentLanguage.hinglish: 'Doctor Review',
    },
    'regimen_prescribed': {
      AssessmentLanguage.english: 'Regimen Prescribed',
      AssessmentLanguage.hindi: 'उपचार योजना निर्धारित',
      AssessmentLanguage.hinglish: 'Regimen Prescribed',
    },

    // Updated 3-step tracker labels
    'intake_done': {
      AssessmentLanguage.english: 'Intake Done',
      AssessmentLanguage.hindi: 'जानकारी दर्ज',
      AssessmentLanguage.hinglish: 'Intake Done',
    },
    'ai_review_done': {
      AssessmentLanguage.english: 'AI Review Done',
      AssessmentLanguage.hindi: 'AI समीक्षा पूर्ण',
      AssessmentLanguage.hinglish: 'AI Review Done',
    },
    'doctor_review_step': {
      AssessmentLanguage.english: 'Doctor Review',
      AssessmentLanguage.hindi: 'डॉक्टर समीक्षा',
      AssessmentLanguage.hinglish: 'Doctor Review',
    },
    'review_timeline_intake': {
      AssessmentLanguage.english: 'Submitted',
      AssessmentLanguage.hindi: 'जमा हुआ',
      AssessmentLanguage.hinglish: 'Submit hua',
    },
    'review_timeline_result': {
      AssessmentLanguage.english: 'Result',
      AssessmentLanguage.hindi: 'रिज़ल्ट',
      AssessmentLanguage.hinglish: 'Result',
    },
    'review_timeline_clinician': {
      AssessmentLanguage.english: 'Clinician',
      AssessmentLanguage.hindi: 'डॉक्टर',
      AssessmentLanguage.hinglish: 'Doctor',
    },
    'review_timeline_optional': {
      AssessmentLanguage.english: 'Optional',
      AssessmentLanguage.hindi: 'ज़रूरी नहीं',
      AssessmentLanguage.hinglish: 'Optional',
    },
    'review_status_processing_badge': {
      AssessmentLanguage.english: 'PREPARING',
      AssessmentLanguage.hindi: 'तैयार हो रहा है',
      AssessmentLanguage.hinglish: 'READY HO RAHA HAI',
    },
    'review_status_processing_title': {
      AssessmentLanguage.english: 'Preparing your result',
      AssessmentLanguage.hindi: 'आपका रिज़ल्ट तैयार हो रहा है',
      AssessmentLanguage.hinglish: 'Aapka result ready ho raha hai',
    },
    'review_status_processing_body': {
      AssessmentLanguage.english: 'Your assessment is being processed.',
      AssessmentLanguage.hindi: 'आपकी जाँच पर काम चल रहा है।',
      AssessmentLanguage.hinglish: 'Aapki assessment process ho rahi hai.',
    },
    'review_status_clinician_badge': {
      AssessmentLanguage.english: 'Assessment Submitted',
      AssessmentLanguage.hindi: 'जाँच जमा की गई',
      AssessmentLanguage.hinglish: 'Assessment Submit Ho Chuka Hai',
    },
    'review_status_clinician_title': {
      AssessmentLanguage.english: 'Your assessment is ready',
      AssessmentLanguage.hindi: 'आपकी रिपोर्ट तैयार है',
      AssessmentLanguage.hinglish: 'Aapki assessment report ready hai',
    },
    'review_status_clinician_body': {
      AssessmentLanguage.english:
          'A clinician review is needed before care suggestions are shown.',
      AssessmentLanguage.hindi:
          'देखभाल के सुझाव देखने से पहले डॉक्टर की समीक्षा आवश्यक है।',
      AssessmentLanguage.hinglish:
          'Care suggestions dekhne ke liye pehle doctor ka review zaroori hai.',
    },
    'review_status_under_review_badge': {
      AssessmentLanguage.english: 'UNDER REVIEW',
      AssessmentLanguage.hindi: 'समीक्षा जारी',
      AssessmentLanguage.hinglish: 'REVIEW CHAL RAHA HAI',
    },
    'review_status_under_review_title': {
      AssessmentLanguage.english: 'Doctor review in progress',
      AssessmentLanguage.hindi: 'डॉक्टर की समीक्षा जारी है',
      AssessmentLanguage.hinglish: 'Doctor review chal raha hai',
    },
    'review_status_under_review_body': {
      AssessmentLanguage.english: 'We’ll show the update here when ready.',
      AssessmentLanguage.hindi: 'अपडेट तैयार होने पर यहाँ दिखेगा।',
      AssessmentLanguage.hinglish: 'Update ready hote hi yahan dikhega.',
    },
    'review_status_reviewed_badge': {
      AssessmentLanguage.english: 'REVIEW COMPLETE',
      AssessmentLanguage.hindi: 'समीक्षा पूरी',
      AssessmentLanguage.hinglish: 'REVIEW COMPLETE',
    },
    'review_status_reviewed_title': {
      AssessmentLanguage.english: 'Doctor review complete',
      AssessmentLanguage.hindi: 'डॉक्टर की समीक्षा पूरी',
      AssessmentLanguage.hinglish: 'Doctor review poora hua',
    },
    'review_status_reviewed_body': {
      AssessmentLanguage.english: 'Your care plan is ready to view.',
      AssessmentLanguage.hindi: 'आपकी केयर योजना देखने के लिए तैयार है।',
      AssessmentLanguage.hinglish: 'Aapka care plan dekhne ke liye ready hai.',
    },
    'review_status_reviewed_note': {
      AssessmentLanguage.english: 'Your doctor’s note is ready to view.',
      AssessmentLanguage.hindi: 'डॉक्टर का नोट देखने के लिए तैयार है।',
      AssessmentLanguage.hinglish: 'Doctor ka note dekhne ke liye ready hai.',
    },
    'review_status_reviewed_recorded': {
      AssessmentLanguage.english: 'Your review has been recorded.',
      AssessmentLanguage.hindi: 'आपकी समीक्षा दर्ज कर ली गई है।',
      AssessmentLanguage.hinglish: 'Aapka review record ho gaya hai.',
    },
    'review_status_ready_badge': {
      AssessmentLanguage.english: 'RESULT READY',
      AssessmentLanguage.hindi: 'रिज़ल्ट तैयार',
      AssessmentLanguage.hinglish: 'RESULT READY',
    },
    'review_status_ready_title': {
      AssessmentLanguage.english: 'Assessment ready',
      AssessmentLanguage.hindi: 'जाँच तैयार है',
      AssessmentLanguage.hinglish: 'Assessment ready hai',
    },
    'review_status_ready_body': {
      AssessmentLanguage.english: 'Your summary and next steps are ready.',
      AssessmentLanguage.hindi: 'आपका सारांश और अगले कदम तैयार हैं।',
      AssessmentLanguage.hinglish: 'Aapka summary aur next steps ready hain.',
    },
    'review_status_failed_badge': {
      AssessmentLanguage.english: 'RESULT UNAVAILABLE',
      AssessmentLanguage.hindi: 'रिज़ल्ट उपलब्ध नहीं',
      AssessmentLanguage.hinglish: 'RESULT NAHI MILA',
    },
    'review_status_failed_title': {
      AssessmentLanguage.english: 'Result not ready yet',
      AssessmentLanguage.hindi: 'रिज़ल्ट अभी तैयार नहीं',
      AssessmentLanguage.hinglish: 'Result abhi ready nahi hai',
    },
    'review_status_failed_body': {
      AssessmentLanguage.english: 'Open your report to check the next step.',
      AssessmentLanguage.hindi: 'अगला कदम देखने के लिए रिपोर्ट खोलें।',
      AssessmentLanguage.hinglish: 'Agla step dekhne ke liye report kholein.',
    },
    'review_action_view': {
      AssessmentLanguage.english: 'View report',
      AssessmentLanguage.hindi: 'रिपोर्ट देखें',
      AssessmentLanguage.hinglish: 'Report dekhein',
    },
    'review_action_request': {
      AssessmentLanguage.english: 'Contact doctor on WhatsApp',
      AssessmentLanguage.hindi: 'डॉक्टर से WhatsApp करें',
      AssessmentLanguage.hinglish: 'Contact doctor on WhatsApp',
    },
    'whatsapp_doctor_btn': {
      AssessmentLanguage.english: 'Ask Doctor',
      AssessmentLanguage.hindi: 'डॉक्टर से पूछें',
      AssessmentLanguage.hinglish: 'Doctor Se Puchein',
    },

    // Bottom nav buttons
    'whatsapp_doctor_bottom': {
      AssessmentLanguage.english: 'WhatsApp Doctor',
      AssessmentLanguage.hindi: 'डॉक्टर से WhatsApp करें',
      AssessmentLanguage.hinglish: 'WhatsApp Doctor',
    },
    'retake_hair_test': {
      AssessmentLanguage.english: 'Retest',
      AssessmentLanguage.hindi: 'पुनः जाँच',
      AssessmentLanguage.hinglish: 'Retest Karein',
    },

    // Overview & Diagnosis Card
    'assessment_overview': {
      AssessmentLanguage.english: 'ASSESSMENT OVERVIEW',
      AssessmentLanguage.hindi: 'जाँच अवलोकन',
      AssessmentLanguage.hinglish: 'ASSESSMENT OVERVIEW',
    },
    'selected_pattern': {
      AssessmentLanguage.english: 'Your selected pattern',
      AssessmentLanguage.hindi: 'आपका चुना हुआ पैटर्न',
      AssessmentLanguage.hinglish: 'Aapka Chuna Hua Pattern',
    },
    'pattern_matches_reported': {
      AssessmentLanguage.english:
          'Matches your self-reported hairline or crown shedding.',
      AssessmentLanguage.hindi:
          'यह आपके द्वारा बताए गए हेयरलाइन या क्राउन शेडिंग से मेल खाता है।',
      AssessmentLanguage.hinglish:
          'Aapke bataye hairline ya crown shedding pattern se match karta hai.',
    },
    'reported_concern': {
      AssessmentLanguage.english: 'Your reported concern',
      AssessmentLanguage.hindi: 'आपकी बताई गई समस्या',
      AssessmentLanguage.hinglish: 'Aapki Batayi Gayi Problem',
    },

    // Scalp Photos Gallery
    'clinical_scalp_photos': {
      AssessmentLanguage.english: 'Clinical Scalp Photos',
      AssessmentLanguage.hindi: 'स्कैल्प की क्लिनिकल तस्वीरें',
      AssessmentLanguage.hinglish: 'Aapke Scalp Photos',
    },
    'scalp_photos_notice': {
      AssessmentLanguage.english: 'AI checks that photos show a scalp; it does not diagnose from images.',
      AssessmentLanguage.hindi: 'एआई केवल फ़ोटो की गुणवत्ता जाँचता है; अंतिम निदान डॉक्टर द्वारा किया जाता है।',
      AssessmentLanguage.hinglish: 'AI photos verify karta hai; complete diagnosis clinical review se hoti hai.',
    },
    'tap_to_zoom': {
      AssessmentLanguage.english: 'Tap any photo to view full-screen & zoom',
      AssessmentLanguage.hindi:
          'बड़ा करके देखने और ज़ूम करने के लिए फ़ोटो छुएँ',
      AssessmentLanguage.hinglish:
          'Full-screen zoom ke liye kisi bhi photo par tap karein',
    },
    'no_scalp_photos': {
      AssessmentLanguage.english: 'No scalp photos attached',
      AssessmentLanguage.hindi: 'कोई स्कैल्प तस्वीर संलग्न नहीं है',
      AssessmentLanguage.hinglish: 'Koi scalp photo attach nahi hai',
    },
    'scalp_photos_benefit_desc': {
      AssessmentLanguage.english: 'Clear scalp photos help doctors review follicle density and crown patterns more accurately.',
      AssessmentLanguage.hindi: 'स्पष्ट तस्वीरें डॉक्टरों को फॉलिकल डेंसिटी और क्राउन पैटर्न का सटीक विश्लेषण करने में मदद करती हैं।',
      AssessmentLanguage.hinglish: 'Clear photos se doctor follicle density aur crown pattern accurate analyze kar paate hain.',
    },
    'photo_front': {
      AssessmentLanguage.english: 'Front Hairline',
      AssessmentLanguage.hindi: 'आगे की हेयरलाइन',
      AssessmentLanguage.hinglish: 'Front Hairline',
    },
    'photo_top': {
      AssessmentLanguage.english: 'Top View',
      AssessmentLanguage.hindi: 'ऊपर का हिस्सा',
      AssessmentLanguage.hinglish: 'Top View',
    },
    'photo_top_crown': {
      AssessmentLanguage.english: 'Top / Crown',
      AssessmentLanguage.hindi: 'ऊपर / क्राउन',
      AssessmentLanguage.hinglish: 'Top / Crown Area',
    },
    'photo_crown': {
      AssessmentLanguage.english: 'Crown Vertex',
      AssessmentLanguage.hindi: 'क्राउन (सिर का ऊपरी मध्य)',
      AssessmentLanguage.hinglish: 'Crown Area',
    },
    'photo_left': {
      AssessmentLanguage.english: 'Side Profile / Temples',
      AssessmentLanguage.hindi: 'साइड प्रोफ़ाइल / कनपटी',
      AssessmentLanguage.hinglish: 'Side Profile / Temples',
    },
    'photo_side': {
      AssessmentLanguage.english: 'Side Profile / Temples',
      AssessmentLanguage.hindi: 'साइड प्रोफ़ाइल / कनपटी',
      AssessmentLanguage.hinglish: 'Side Profile / Temples',
    },
    'tab_possible_factors': {
      AssessmentLanguage.english: 'Possible factors',
      AssessmentLanguage.hindi: 'संभावित कारक',
      AssessmentLanguage.hinglish: 'Possible factors',
    },
    'tab_diet_plan': {
      AssessmentLanguage.english: 'Diet Plan',
      AssessmentLanguage.hindi: 'डाइट प्लान',
      AssessmentLanguage.hinglish: 'Diet Plan',
    },
    'tab_lifestyle': {
      AssessmentLanguage.english: 'Lifestyle',
      AssessmentLanguage.hindi: 'जीवनशैली',
      AssessmentLanguage.hinglish: 'Lifestyle',
    },
    'tab_regimen': {
      AssessmentLanguage.english: 'Regimen',
      AssessmentLanguage.hindi: 'दैनिक दिनचर्या',
      AssessmentLanguage.hinglish: 'Daily Routine',
    },
    'ai_guidance_disclaimer': {
      AssessmentLanguage.english:
          'Questionnaire-based guidance only · Not a diagnosis',
      AssessmentLanguage.hindi:
          'केवल प्रश्नावली आधारित मार्गदर्शन · यह कोई चिकित्सीय निदान नहीं है',
      AssessmentLanguage.hinglish:
          'Questionnaire based guidance only · Ye medical diagnosis nahi hai',
    },
    'screening_result': {
      AssessmentLanguage.english: 'Screening result',
      AssessmentLanguage.hindi: 'स्क्रीनिंग रिज़ल्ट',
      AssessmentLanguage.hinglish: 'Screening result',
    },
    'photo_right': {
      AssessmentLanguage.english: 'Right Temple',
      AssessmentLanguage.hindi: 'दायाँ सिरा (Right Temple)',
      AssessmentLanguage.hinglish: 'Right Temple',
    },
    'photo_back': {
      AssessmentLanguage.english: 'Back Scalp',
      AssessmentLanguage.hindi: 'सिर का पिछला हिस्सा',
      AssessmentLanguage.hinglish: 'Back Scalp',
    },
    'ai_verified_badge': {
      AssessmentLanguage.english: 'AI Verified',
      AssessmentLanguage.hindi: 'एआई सत्यापित',
      AssessmentLanguage.hinglish: 'AI Verified',
    },
    'assessment_intake_badge': {
      AssessmentLanguage.english: 'Assessment Intake',
      AssessmentLanguage.hindi: 'मूल्यांकन तस्वीरें',
      AssessmentLanguage.hinglish: 'Intake Photos',
    },
    'ai_clinical_observation': {
      AssessmentLanguage.english: 'AI Scalp Analysis & Observations',
      AssessmentLanguage.hindi: 'एआई स्कैल्प विश्लेषण और टिप्पणियाँ',
      AssessmentLanguage.hinglish: 'AI Scalp Analysis & Insights',
    },
    'not_uploaded': {
      AssessmentLanguage.english: 'Not uploaded',
      AssessmentLanguage.hindi: 'अपलोड नहीं है',
      AssessmentLanguage.hinglish: 'Uploaded nahi hai',
    },
    'close': {
      AssessmentLanguage.english: 'Close',
      AssessmentLanguage.hindi: 'बंद करें',
      AssessmentLanguage.hinglish: 'Close',
    },

    // Doctor Prescribed Care Plan
    'clinical_care_plan': {
      AssessmentLanguage.english: 'Clinical care plan',
      AssessmentLanguage.hindi: 'चिकित्सीय उपचार योजना',
      AssessmentLanguage.hinglish: 'Doctor Care Plan',
    },
    'regimen_instructions': {
      AssessmentLanguage.english: 'Clinical Regimen Instructions',
      AssessmentLanguage.hindi: 'उपचार और उपयोग निर्देश',
      AssessmentLanguage.hinglish: 'Regimen Aur Usage Instructions',
    },
    'prescribed_formulations': {
      AssessmentLanguage.english: 'Prescribed Formulations & Dosage',
      AssessmentLanguage.hindi: 'निर्धारित दवाइयाँ और ख़ुराक',
      AssessmentLanguage.hinglish: 'Prescribed Medicines Aur Dosage',
    },
    'next_clinical_review': {
      AssessmentLanguage.english: 'Next Clinical Review',
      AssessmentLanguage.hindi: 'अगली क्लिनिकल समीक्षा',
      AssessmentLanguage.hinglish: 'Next Doctor Review',
    },

    // Doctor Clinical Documents
    'clinical_documents': {
      AssessmentLanguage.english: 'Clinical documents',
      AssessmentLanguage.hindi: 'क्लिनिकल दस्तावेज़',
      AssessmentLanguage.hinglish: 'Clinical Documents',
    },
    'shared_with_care_team': {
      AssessmentLanguage.english: 'Shared with your care team',
      AssessmentLanguage.hindi: 'आपकी केयर टीम द्वारा साझा किए गए',
      AssessmentLanguage.hinglish: 'Care team ke saath shared',
    },
    'clinical_documents_desc': {
      AssessmentLanguage.english:
          'Documents shared with you by the clinic are available below.',
      AssessmentLanguage.hindi:
          'क्लिनिक द्वारा आपके साथ साझा किए गए दस्तावेज़ नीचे उपलब्ध हैं।',
      AssessmentLanguage.hinglish:
          'Clinic dwara share kiye gaye official documents neeche hain.',
    },
    'view_pdf': {
      AssessmentLanguage.english: 'View PDF',
      AssessmentLanguage.hindi: 'पीडीएफ़ देखें',
      AssessmentLanguage.hinglish: 'View PDF',
    },
    'order_kit': {
      AssessmentLanguage.english: 'Order Kit',
      AssessmentLanguage.hindi: 'किट मंगाएँ',
      AssessmentLanguage.hinglish: 'Order Kit',
    },

    // Summary Card
    'what_you_shared': {
      AssessmentLanguage.english: 'WHAT YOU SHARED',
      AssessmentLanguage.hindi: 'साझा की गई जानकारी',
      AssessmentLanguage.hinglish: 'AAPKI SHARED DETAILS',
    },
    'what_you_shared_desc': {
      AssessmentLanguage.english:
          'These are the details you selected for this assessment.',
      AssessmentLanguage.hindi:
          'यह वे विवरण हैं जो आपने इस जाँच के दौरान दर्ज किए थे।',
      AssessmentLanguage.hinglish:
          'Ye details aapne assessment submit karte time select ki thi.',
    },
    'gender': {
      AssessmentLanguage.english: 'Gender',
      AssessmentLanguage.hindi: 'लिंग',
      AssessmentLanguage.hinglish: 'Gender',
    },
    'age': {
      AssessmentLanguage.english: 'Age',
      AssessmentLanguage.hindi: 'आयु',
      AssessmentLanguage.hinglish: 'Age (Umar)',
    },
    'main_concern': {
      AssessmentLanguage.english: 'Main Concern',
      AssessmentLanguage.hindi: 'मुख्य समस्या',
      AssessmentLanguage.hinglish: 'Main Concern',
    },
    'duration': {
      AssessmentLanguage.english: 'Duration',
      AssessmentLanguage.hindi: 'कितने समय से',
      AssessmentLanguage.hinglish: 'Kitne Time Se Hai',
    },
    'dandruff_status': {
      AssessmentLanguage.english: 'Dandruff Status',
      AssessmentLanguage.hindi: 'रूसी (Dandruff) की स्थिति',
      AssessmentLanguage.hinglish: 'Dandruff Condition',
    },
    'family_history': {
      AssessmentLanguage.english: 'Family History',
      AssessmentLanguage.hindi: 'पारिवारिक इतिहास',
      AssessmentLanguage.hinglish: 'Family History',
    },
    'gut_health': {
      AssessmentLanguage.english: 'Gut Health',
      AssessmentLanguage.hindi: 'पाचन स्वास्थ्य (Gut Health)',
      AssessmentLanguage.hinglish: 'Digestion / Gut Health',
    },
    'stress_level': {
      AssessmentLanguage.english: 'Stress Level',
      AssessmentLanguage.hindi: 'तनाव का स्तर (Stress Level)',
      AssessmentLanguage.hinglish: 'Stress Level',
    },

    // Disclaimer
    'how_to_use_result': {
      AssessmentLanguage.english: 'How to use this result',
      AssessmentLanguage.hindi: 'इस रिपोर्ट का उपयोग कैसे करें',
      AssessmentLanguage.hinglish: 'Is Result Ko Kaise Use Karein',
    },
    'disclaimer_desc': {
      AssessmentLanguage.english: 'This summary is based on your answers and is not a medical diagnosis. A qualified clinician can assess your symptoms and discuss suitable care.',
      AssessmentLanguage.hindi: 'यह सारांश आपके जवाबों पर आधारित है और यह चिकित्सकीय निदान नहीं है। उपयुक्त देखभाल के लिए डॉक्टर से परामर्श लें।',
      AssessmentLanguage.hinglish: 'Ye summary aapke answers par based hai aur final medical diagnosis nahi hai. Sahi guidance ke liye clinic doctor se consult karein.',
    },

    // Next steps & actions
    'your_next_steps': {
      AssessmentLanguage.english: 'Your next steps',
      AssessmentLanguage.hindi: 'आपके अगले कदम',
      AssessmentLanguage.hinglish: 'Aapke Next Steps',
    },
    'next_steps_desc': {
      AssessmentLanguage.english: 'Start with these simple, non-prescription care steps. Products are optional; a clinician can guide treatment when needed.',
      AssessmentLanguage.hindi: 'इन आसान दैनिक देखभाल चरणों से शुरुआत करें। उत्पाद वैकल्पिक हैं; आवश्यकता पड़ने पर डॉक्टर मार्गदर्शन करेंगे।',
      AssessmentLanguage.hinglish: 'In simple daily care steps se start karein. Products optional hain; zarurat padne par doctor guidance denge.',
    },
    'open_daily_care_routine': {
      AssessmentLanguage.english: 'Open daily care routine',
      AssessmentLanguage.hindi: 'दैनिक देखभाल रूटीन खोलें',
      AssessmentLanguage.hinglish: 'Open daily care routine',
    },
    'whatsapp_doctor': {
      AssessmentLanguage.english: 'WhatsApp doctor',
      AssessmentLanguage.hindi: 'डॉक्टर से व्हाट्सऐप पर बात करें',
      AssessmentLanguage.hinglish: 'WhatsApp doctor',
    },
    'book_consultation': {
      AssessmentLanguage.english: 'Book consultation',
      AssessmentLanguage.hindi: 'परामर्श बुक करें',
      AssessmentLanguage.hinglish: 'Book consultation',
    },
    'download_pdf': {
      AssessmentLanguage.english: 'Download PDF',
      AssessmentLanguage.hindi: 'पीडीएफ़ डाउनलोड करें',
      AssessmentLanguage.hinglish: 'Download PDF',
    },
    'share_summary': {
      AssessmentLanguage.english: 'Share Summary',
      AssessmentLanguage.hindi: 'सारांश साझा करें',
      AssessmentLanguage.hinglish: 'Share Summary',
    },
    'in_person_consultation_recommended': {
      AssessmentLanguage.english: 'In-Person Clinical Consultation Recommended',
      AssessmentLanguage.hindi:
          'क्लिनिक में प्रत्यक्ष परामर्श की सलाह दी जाती है',
      AssessmentLanguage.hinglish: 'In-Person Clinic Consultation Recommended',
    },
    'contact_doctor_whatsapp': {
      AssessmentLanguage.english: 'Contact doctor on WhatsApp',
      AssessmentLanguage.hindi: 'व्हाट्सऐप पर डॉक्टर से संपर्क करें',
      AssessmentLanguage.hinglish: 'Contact doctor on WhatsApp',
    },
  };

  /// Translate a static key. Fallback to English if key or language is not found.
  static String t(String key, AssessmentLanguage lang) {
    final entry = _strings[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[AssessmentLanguage.english] ?? key;
  }

  /// Dynamic Scalp Health Score translation
  static String getScalpScoreText(int score, AssessmentLanguage lang) {
    switch (lang) {
      case AssessmentLanguage.english:
        return 'Your scalp health score is $score/100. Hair fall control is achievable with a consistent regimen.';
      case AssessmentLanguage.hindi:
        return 'आपका स्कैल्प हेल्थ स्कोर $score/100 है। नियमित देखभाल और सही रूटीन से बालों का झड़ना रोका जा सकता है।';
      case AssessmentLanguage.hinglish:
        return 'Aapka scalp health score $score/100 hai. Hair fall control ke liye regular routine bohot zaroori hai.';
    }
  }

  /// Dynamic Stage Title translation
  static String translateStage(String? stage, AssessmentLanguage lang) {
    if (stage == null || stage.trim().isEmpty) return 'Stage 1';
    final normalized = stage.trim();

    if (lang == AssessmentLanguage.english) return normalized;

    if (normalized.contains('Stage 1')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्टेज 1 - शुरुआती हेयर शेडिंग'
          : 'Stage 1 - Early Thinning / Shedding';
    }
    if (normalized.contains('Stage 2')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्टेज 2 - पीछे हटती हेयरलाइन'
          : 'Stage 2 - Receding Hairline';
    }
    if (normalized.contains('Stage 3')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्टेज 3 - क्राउन और मंदिर क्षेत्र में पतलापन'
          : 'Stage 3 - Crown & Temple Thinning';
    }
    if (normalized.contains('Stage 4')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्टेज 4 - एडवांस हेयर थिनिंग'
          : 'Stage 4 - Advanced Thinning';
    }
    if (normalized.contains('Stage 5')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्टेज 5 - गंभीर बालों का झड़ना'
          : 'Stage 5 - Advanced Crown Thinning';
    }

    return normalized;
  }

  /// Dynamic Severity translation
  static String translateSeverity(String? severity, AssessmentLanguage lang) {
    if (severity == null || severity.trim().isEmpty) return 'Moderate';
    final s = severity.trim().toLowerCase();

    if (lang == AssessmentLanguage.english) {
      if (s.contains('mild')) return 'Mild';
      if (s.contains('mod')) return 'Moderate';
      if (s.contains('crit')) return 'Critical';
      if (s.contains('sev')) return 'Severe';
      return severity;
    }

    if (lang == AssessmentLanguage.hindi) {
      if (s.contains('mild')) return 'हल्का (Mild)';
      if (s.contains('mod')) return 'मध्यम (Moderate)';
      if (s.contains('crit')) return 'अति गंभीर (Critical)';
      if (s.contains('sev')) return 'गंभीर (Severe)';
      return severity;
    }

    // Hinglish
    if (s.contains('mild')) return 'Mild / Shuruaati';
    if (s.contains('mod')) return 'Moderate / Madhyam';
    if (s.contains('crit')) return 'Critical / Urgent Dhyan';
    if (s.contains('sev')) return 'Severe / Zyada';
    return severity;
  }

  /// Dynamic Root Cause Factor translation
  static String translateRootCauseFactor(
    String factor,
    AssessmentLanguage lang,
  ) {
    if (lang == AssessmentLanguage.english) return factor;
    final f = factor.toLowerCase();

    if (f.contains('dht') || f.contains('follicle')) {
      return lang == AssessmentLanguage.hindi
          ? 'डीएचटी संवेदनशीलता (DHT Sensitivity)'
          : 'DHT Sensitivity (Follicle Weakness)';
    }
    if (f.contains('nutrit') || f.contains('defic') || f.contains('diet')) {
      return lang == AssessmentLanguage.hindi
          ? 'पोषक तत्वों की कमी (Nutritional Deficiency)'
          : 'Nutritional Deficiency (Iron/Biotin/Protein)';
    }
    if (f.contains('stress') || f.contains('cortisol')) {
      return lang == AssessmentLanguage.hindi
          ? 'तनाव और हार्मोनल असंतुलन'
          : 'Stress / High Cortisol Level';
    }
    if (f.contains('circul') || f.contains('blood')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्कैल्प में कम रक्त संचार'
          : 'Scalp Blood Flow / Circulation Issue';
    }
    if (f.contains('dandruff') ||
        f.contains('sebum') ||
        f.contains('seborrheic')) {
      return lang == AssessmentLanguage.hindi
          ? 'रूसी और सीबम जमाव (Dandruff Build-up)'
          : 'Dandruff & Scalp Buildup';
    }

    return factor;
  }

  /// Dynamic Root Cause Explanation translation
  static String translateRootCauseExplanation(
    String factor,
    String originalExplanation,
    AssessmentLanguage lang,
  ) {
    if (lang == AssessmentLanguage.english ||
        originalExplanation.trim().isEmpty) {
      return originalExplanation;
    }

    final f = factor.toLowerCase();
    if (f.contains('dht')) {
      return lang == AssessmentLanguage.hindi
          ? 'डीएचटी हार्मोन बालों के फॉलिकल्स को छोटा कर देता है, जिससे बाल पतले होकर समय से पहले झड़ने लगते हैं।'
          : 'DHT hormone hair follicles ko shrink kar deta hai, jisse baal patle ho kar jhadne lagte hain.';
    }
    if (f.contains('nutrit')) {
      return lang == AssessmentLanguage.hindi
          ? 'आहार में प्रोटीन, आयरन या बायोटिन की कमी बालों की जड़ों को पोषण मिलने से रोकती है।'
          : 'Khaane me protein, iron ya biotin ki kami se baalon ki jado ko pura poshan nahi mil pata.';
    }
    if (f.contains('stress')) {
      return lang == AssessmentLanguage.hindi
          ? 'उच्च तनाव कोर्टिसोल स्तर बढ़ाता है, जिससे अधिक बाल समय से पहले रेस्टिंग (शेडिंग) फेज में चले जाते हैं।'
          : 'High stress se cortisol badhta hai jisse baal telogen (shedding) phase me chale jaate hain.';
    }
    if (f.contains('circul')) {
      return lang == AssessmentLanguage.hindi
          ? 'स्कैल्प तक रक्त संचार कम होने से बालों के रोम छिद्रों को आवश्यक ऑक्सीजन नहीं मिल पाती।'
          : 'Scalp me circulation kam hone se hair roots tak oxygen aur nutrients efficiently nahi pahuchte.';
    }
    if (f.contains('dandruff')) {
      return lang == AssessmentLanguage.hindi
          ? 'रूसी और अत्यधिक तेल रोम छिद्रों को बंद कर देते हैं, जिससे स्कैल्प में जलन और बाल झड़ने लगते हैं।'
          : 'Dandruff aur excess oil follicles ko clog kar deta hai jisse scalp me itching aur hair fall hota hai.';
    }

    return originalExplanation;
  }
}
