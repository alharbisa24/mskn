const express = require('express');
const router = express.Router();

// Use built-in fetch for Node 18+ or node-fetch for older versions
let fetch;
try {
  fetch = globalThis.fetch || require('node-fetch');
} catch (e) {
  fetch = require('node-fetch');
}

// Using Hugging Face as the AI provider

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
    
    const { type, amount, questions_answers, points } = req.body;

    // Log received data
    console.log('📋 Received Data:');
    console.log('   Property Type:', type);
    console.log('   Budget:', amount, 'SAR');
    console.log('   Questions & Answers:', questions_answers?.length || 0, 'questions');
    console.log('   Reference Points:', points?.length || 0, 'points');
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
    const TEST_MODE = process.env.TEST_MODE !== 'false'; // Defaults to true, set TEST_MODE=false to disable
    
    if (TEST_MODE) {
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

    // Validate API key (only when not in test mode)
    if (!process.env.HUGGINGFACE_API_KEY) {
      return res.status(500).json({
        success: false,
        message: 'HUGGINGFACE_API_KEY is not set in environment variables'
      });
    }

    // Build prompt for AI
    let prompt = `You are a real estate assistant helping to find the best property locations in Riyadh, Saudi Arabia.\n\n`;
    prompt += `Property Type: ${type}\n`;
    prompt += `Budget: ${amount} SAR\n\n`;
    prompt += `User Preferences (Questions & Answers):\n`;
    
    questions_answers.forEach((qa, index) => {
      prompt += `${index + 1}. ${qa.question}: ${qa.answer}\n`;
    });
    
    prompt += `\nReference Points (User's preferred areas):\n`;
    points.forEach((point, index) => {
      prompt += `${index + 1}. Latitude: ${point.latitude}, Longitude: ${point.longitude}\n`;
    });
    
    prompt += `\nBased on the user's preferences and reference points, recommend exactly 8 locations in Riyadh that match their criteria.\n`;
    prompt += `For each location, provide:\n`;
    prompt += `- Name: The full address/neighborhood name in Arabic\n`;
    prompt += `- Coordinates: An array with a single coordinate object containing latitude and longitude (must be near the reference points, within Riyadh area)\n`;
    prompt += `- Color: You must provide exactly 4 locations with "green" (good matches), 2 locations with "yellow" (medium matches), and 2 locations with "red" (poor matches)\n\n`;
    prompt += `IMPORTANT: You must respond in the EXACT same format as shown below. The example below shows the JSON structure only - DO NOT use these example names or coordinates. Generate your own location names and coordinates based on the user's preferences and reference points.\n\n`;
    prompt += `Example format (DO NOT copy these exact values, use them only as a structure reference):\n`;
    prompt += `{\n`;
    prompt += `  "points": [\n`;
    prompt += `    {\n`;
    prompt += `      "Name": "[Example: حي النرجس، شمال الرياض، المملكة العربية السعودية]",\n`;
    prompt += `      "coordinates": [\n`;
    prompt += `        {"latitude": 24.7136, "longitude": 46.6753}\n`;
    prompt += `      ],\n`;
    prompt += `      "color": "green"\n`;
    prompt += `    },\n`;
    prompt += `    {\n`;
    prompt += `      "Name": "[Example: حي الياسمين، شمال الرياض، المملكة العربية السعودية]",\n`;
    prompt += `      "coordinates": [\n`;
    prompt += `        {"latitude": 24.7200, "longitude": 46.6800}\n`;
    prompt += `      ],\n`;
    prompt += `      "color": "yellow"\n`;
    prompt += `    },\n`;
    prompt += `    {\n`;
    prompt += `      "Name": "[Example: حي الصحافة، شمال الرياض، المملكة العربية السعودية]",\n`;
    prompt += `      "coordinates": [\n`;
    prompt += `        {"latitude": 24.7255, "longitude": 46.6855}\n`;
    prompt += `      ],\n`;
    prompt += `      "color": "red"\n`;
    prompt += `    }\n`;
    prompt += `  ]\n`;
    prompt += `}\n\n`;
    prompt += `Each point must have:\n`;
    prompt += `- "Name": Full Arabic address/neighborhood name\n`;
    prompt += `- "coordinates": An array with a single object containing "latitude" and "longitude" properties\n`;
    prompt += `- "color": Must be exactly 4 "green", 2 "yellow", and 2 "red" (8 total points)\n\n`;
    prompt += `IMPORTANT: Generate NEW location names and coordinates based on the user's preferences and reference points provided above. Do NOT copy the example names or coordinates. Make sure coordinates are realistic locations in Riyadh near the reference points. Return ONLY the JSON object with "points" array containing exactly 8 locations with the specified color distribution (4 green, 2 yellow, 2 red), no additional text or explanation.`;

    // Send to AI model using Hugging Face
    const modelName = process.env.HUGGINGFACE_MODEL || 'mistralai/Mistral-7B-Instruct-v0.2';
    const hfResponse = await fetch(
      `https://api-inference.huggingface.co/models/${modelName}`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${process.env.HUGGINGFACE_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          inputs: `<s>[INST] ${process.env.SYSTEM_PROMPT || 'You are a helpful real estate assistant. Always respond with valid JSON only, no additional text.'}\n\n${prompt} [/INST]`,
          parameters: {
            temperature: 0.7,
            max_new_tokens: 2000,
            return_full_text: false,
          }
        }),
      }
    );

    if (!hfResponse.ok) {
      const errorData = await hfResponse.text();
      throw new Error(`Hugging Face API error: ${hfResponse.status} - ${errorData}`);
    }

    const hfData = await hfResponse.json();
    // Hugging Face returns an array, get the first element's generated text
    const aiResponse = Array.isArray(hfData) ? hfData[0].generated_text : hfData.generated_text || hfData[0]?.generated_text || JSON.stringify(hfData);
    
    // Parse AI response
    let parsedResponse;
    try {
      // Clean response - remove markdown code blocks if present
      let cleanedResponse = aiResponse.trim();
      if (cleanedResponse.startsWith('```json')) {
        cleanedResponse = cleanedResponse.replace(/```json\n?/g, '').replace(/```\n?/g, '');
      } else if (cleanedResponse.startsWith('```')) {
        cleanedResponse = cleanedResponse.replace(/```\n?/g, '');
      }
      
      // Try parsing the whole response
      parsedResponse = JSON.parse(cleanedResponse);
      
      // If it's an object with points, extract it
      if (parsedResponse.points && Array.isArray(parsedResponse.points)) {
        parsedResponse = parsedResponse.points;
      } else if (Array.isArray(parsedResponse)) {
        // Already an array, use as is
      } else {
        // If it's a single object, wrap it in array
        parsedResponse = [parsedResponse];
      }
    } catch (parseError) {
      console.error('Error parsing AI response:', parseError);
      console.error('Raw response:', aiResponse);
      return res.status(500).json({
        success: false,
        message: 'Failed to parse AI response',
        error: parseError.message,
        rawResponse: aiResponse
      });
    }

    // Ensure parsedResponse is an array
    if (!Array.isArray(parsedResponse)) {
      parsedResponse = [parsedResponse];
    }

    // Validate each point has required fields
    const validatedPoints = parsedResponse.map((point, index) => {
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



