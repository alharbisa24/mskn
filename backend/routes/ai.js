const express = require('express');
const router = express.Router();

// Use built-in fetch for Node 18+ or node-fetch for older versions
let fetch;
try {
  fetch = globalThis.fetch || require('node-fetch');
} catch (e) {
  fetch = require('node-fetch');
}

// Using Hugging Face Space as the AI provider
// NOTE: For simplicity we call the public Space HTTP API directly instead of the router.
// Space: https://Alfatesh-mskn-riyadh-recommender.hf.space
const IS_TEST_MODE = false; // change to true if you want to force mock data
const SPACE_URL = 'https://Alfatesh-mskn-riyadh-recommender.hf.space/predict';

// Hard-coded neighborhood average prices loaded from `average_prices arabic.csv`
// These are sent to the Space under "neighborhood_price_info" and can be used
// by future versions of the model.
const NEIGHBORHOOD_PRICE_INFO = {
  'حي احد': 915000,
  'حي اشبيلية': 1775000,
  'حي الازدهار': 2069200,
  'حي البديعة': 2000000,
  'حي التعاون': 1499000,
  'حي الجرادية': 5500000,
  'حي الجنادرية': 1086710,
  'حي الحائر': 300450,
  'حي الحزم': 883936.1765,
  'حي الحمراء': 2975125,
  'حي الخالدية': 843000,
  'حي الخليج': 1539142.857,
  'حي الدار البيضاء': 558984.2105,
  'حي الربوة': 1300000,
  'حي الربيع': 3800000,
  'حي الرحمانية': 7680000,
  'حي الرمال': 1292908.182,
  'حي الروابي': 1402500,
  'حي الروضة': 2317725.364,
  'حي الرياض': 863984.875,
  'حي الريان': 2012500,
  'حي الزاهر': 712708.25,
  'حي الزهرة': 668035.7143,
  'حي السحاب': 660000,
  'حي السعادة': 997187.5,
  'حي السليمانية': 3004250,
  'حي السويدي': 632631.5789,
  'حي السويدي الغربي': 950000,
  'حي الشعلة': 550,
  'حي الشفا': 722499.75,
  'حي الشهداء': 1690200,
  'حي الصحافة': 5099142.857,
  'حي الصفا': 12499500,
  'حي الضباط': 3700000,
  'حي العارض': 2078962.687,
  'حي العريجاء': 1000000,
  'حي العريجاء الغربية': 615000,
  'حي العريجاء الوسطى': 1666666.667,
  'حي العزيزية': 873500,
  'حي العقيق': 3187500,
  'حي العلا': 535,
  'حي العليا': 3088572.222,
  'حي العمل': 1400000,
  'حي العوالي': 735263.1579,
  'حي العود': 540000,
  'حي الغنامية': 360450,
  'حي الفاروق': 1700000,
  'حي الفيحاء': 2320000,
  'حي القادسية': 1075469.697,
  'حي القيروان': 5265714.286,
  'حي المرسلات': 10000,
  'حي المرقب': 280000,
  'حي المروة': 360000,
  'حي المروج': 1519000,
  'حي المشرق': 1900000,
  'حي المصفاة': 1729950,
  'حي المصيف': 1100000,
  'حي المعذر': 1500000,
  'حي المعيزلة': 1376000,
  'حي المغرزات': 6714333.333,
  'حي الملز': 4250000,
  'حي الملقا': 5156000,
  'حي الملك عبدالله': 9000000,
  'حي الملك فهد': 4800000,
  'حي الملك فيصل': 1383428.571,
  'حي المنصورية': 6000000,
  'حي المهدية': 2479853.659,
  'حي المونسية': 1848384.233,
  'حي النخيل': 1497500,
  'حي الندى': 3000000,
  'حي النرجس': 3349515.625,
  'حي النزهة': 3475000,
  'حي النسيم الشرقي': 775637.5,
  'حي النسيم الغربي': 326500,
  'حي النظيم': 1633333.333,
  'حي النفل': 2100000,
  'حي النهضة': 2982000,
  'حي الوادي': 2433333.333,
  'حي الورود': 4666666.667,
  'حي الوسام': 630000,
  'حي الياسمين': 3475086.957,
  'حي اليرموك': 2231666.667,
  'حي بدر': 639533.8462,
  'حي بنبان': 4500000,
  'حي جرير': 7500000,
  'حي حطين': 5940000,
  'حي حي البيان': 1118987.5,
  'حي حي السدره': 1950000,
  'حي ديراب': 910000,
  'حي سدرة': 2350000,
  'حي سلطانة': 1800000,
  'حي شبرا': 855056.1798,
  'حي ضاحية نمار': 974998.5,
  'حي طويق': 881116.0732,
  'حي طيبة': 765454.5455,
  'حي ظهرة لبن': 1108425.774,
  'حي عرقة': 3460000,
  'حي عريض': 290514.6,
  'حي عكاظ': 833181.8182,
  'حي عليشة': 900000,
  'حي غبيرة': 5000000,
  'حي غرناطة': 5500000,
  'حي قرطبة': 2511250,
  'حي لبن': 750000,
  'حي مخطط الخير': 2333333.333,
  'حي مطار الملك خالد الدولي': 3266666.667,
  'حي منفوحة': 965000,
  'حي نمار': 927500,
};

/**
 * POST /api/ai/ask
 * Receives property preferences from frontend and sends to AI model
 * Returns recommended locations with coordinates
 */
router.post('/ask', async (req, res) => {
  try {
    // Log immediately when request is received
    console.log('\n\n');
    console.log('✅ ============================================');
    console.log('🎯 NEW AI REQUEST RECEIVED!');
    console.log('⏰ Time:', new Date().toISOString());
    console.log('============================================');
    console.log('');
    
    const { type, amount, questions_answers, points, neighborhood_price_info } = req.body;

    // Log received data
    console.log('📋 Received Data:');
    console.log('   Property Type:', type);
    console.log('   Budget:', amount, 'SAR');
    console.log('   Questions & Answers:', questions_answers?.length || 0, 'questions');
    console.log('   Reference Points:', points?.length || 0, 'points');
    console.log('');

    console.log('🔧 Effective AI config:', {
      IS_TEST_MODE,
      SPACE_URL,
    });
    console.log('');
    
    if (questions_answers && questions_answers.length > 0) {
      console.log('❓ Questions & Answers Details:');
      questions_answers.forEach((qa, index) => {
        console.log(`   ${index + 1}. ${qa.question}: ${qa.answer}`);
      });
      console.log('');
    }
    
    if (points && points.length > 0) {
      console.log('📍 Reference Points:');
      points.forEach((point, index) => {
        console.log(`   ${index + 1}. Lat: ${point.latitude}, Lng: ${point.longitude}`);
      });
      console.log('');
    }

    // Validate required fields
    if (!type || !amount || !questions_answers || !points) {
      return res.status(400).json({
        success: false,
        message: 'Missing required fields: type, amount, questions_answers, and points are required'
      });
    }

    if (!Array.isArray(questions_answers) || questions_answers.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'questions_answers must be a non-empty array'
      });
    }

    if (!Array.isArray(points) || points.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'points must be a non-empty array'
      });
    }

    // TEST MODE: Return mock response (set TEST_MODE=false in .env to use real AI)
    if (IS_TEST_MODE) {
      console.log('');
      console.log('🧪 TEST MODE: Using mock response (no AI call)');
      console.log('');
      
      // Return mock response matching the expected format
      const mockResponse = {
        points: [
          {
            Name: "حي النرجس، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7136, longitude: 46.6753 }
            ],
            color: "green"
          },
          {
            Name: "حي الياسمين، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7200, longitude: 46.6800 }
            ],
            color: "green"
          },
          {
            Name: "حي العليا، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7300, longitude: 46.6900 }
            ],
            color: "green"
          },
          {
            Name: "حي الملقا، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7400, longitude: 46.7000 }
            ],
            color: "green"
          },
          {
            Name: "حي الصحافة، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7255, longitude: 46.6855 }
            ],
            color: "yellow"
          },
          {
            Name: "حي النفل، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7350, longitude: 46.6950 }
            ],
            color: "yellow"
          },
          {
            Name: "حي العريجاء، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7500, longitude: 46.7100 }
            ],
            color: "red"
          },
          {
            Name: "حي الشفا، شمال الرياض، المملكة العربية السعودية",
            coordinates: [
              { latitude: 24.7600, longitude: 46.7200 }
            ],
            color: "red"
          },
        ]
      };
      
      console.log('✅ TEST MODE: Returning mock response with', mockResponse.points.length, 'locations');
      console.log('');
      console.log('📤 Sending response to frontend...');
      console.log('===========================================');
      console.log('');
      
      return res.json(mockResponse);
    }

    // Call the dedicated Hugging Face Space for recommendations
    console.log('🚀 Calling recommender Space:', SPACE_URL);

    let hfResponse;
    try {
      hfResponse = await fetch(SPACE_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          type,
          amount,
          questions_answers,
          points,
          // Optional extra field for future model versions.
          // Structure suggestion:
          // { "<district_name>": { "average_price": 123456, ... }, ... }
          neighborhood_price_info: neighborhood_price_info || NEIGHBORHOOD_PRICE_INFO,
        }),
      });
    } catch (networkError) {
      console.error('Network error calling Space:', networkError);
      return res.status(502).json({
        success: false,
        message: 'Failed to reach recommender service',
        error: networkError.message,
      });
    }

    console.log('🔍 Space status:', hfResponse.status);

    if (!hfResponse.ok) {
      const errorText = await hfResponse.text();
      console.error('Space error response:', errorText);
      return res.status(502).json({
        success: false,
        message: `Recommender service error: ${hfResponse.status}`,
        error: errorText,
      });
    }

    const hfData = await hfResponse.json();
    console.log('🔍 Raw Space payload:', hfData);

    // Normalize Space response into common { Name, coordinates: [{ latitude, longitude }], color } format
    let pointsFromModel = [];

    if (Array.isArray(hfData.results)) {
      // Space format: { results: [ { district, latitude, longitude, color, ... } ], ... }
      pointsFromModel = hfData.results.map((item, index) => ({
        Name: item.district || `Location ${index + 1}`,
        coordinates: [
          {
            latitude: item.latitude,
            longitude: item.longitude,
          },
        ],
        color: item.color || 'green',
      }));
    } else if (Array.isArray(hfData.points)) {
      // Already in expected format
      pointsFromModel = hfData.points;
    } else if (Array.isArray(hfData)) {
      pointsFromModel = hfData;
    } else {
      console.warn('Unexpected Space response structure, unable to extract points');
    }

    // Validate each point has required fields
    const validatedPoints = pointsFromModel.map((point, index) => {
      if (!point.Name || !point.coordinates || !point.color) {
        console.warn(`Point ${index} missing required fields:`, point);
      }
      return {
        Name: point.Name || `Location ${index + 1}`,
        coordinates: Array.isArray(point.coordinates) 
          ? point.coordinates 
          : point.coordinate 
            ? [point.coordinate] 
            : [{ latitude: 0, longitude: 0 }],
        color: point.color || 'green'
      };
    });

    // Return in the expected format
    console.log('✅ AI Response: Returning', validatedPoints.length, 'recommended locations');
    console.log('===========================================\n');
    
    res.json({
      points: validatedPoints
    });

  } catch (error) {
    console.error('\n❌ ============================================');
    console.error('ERROR processing AI request:', error);
    console.error('===========================================\n');
    res.status(500).json({
      success: false,
      message: 'Error processing request',
      error: error.message
    });
  }
});

module.exports = router;



