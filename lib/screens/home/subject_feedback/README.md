# Subject Feedback System

This folder contains the implementation of the subject feedback system for EduNest.

## Files

### `subject_feedback_list_screen.dart`
- Displays a list of all subjects for the current user's semester
- Allows students to select a subject to provide feedback
- Fetches subjects based on user's college, branch, and semester
- Handles loading states and error cases

### `feedback_form_screen.dart`
- Provides the feedback form interface for a specific subject
- Loads active feedback campaigns from the database
- Allows rating questions and optional comments
- Submits feedback responses to the database

## Database Structure

The feedback system uses the `feedback_data` table with two types of records:

### Campaign Records (type: 'campaign')
- Store feedback campaign configurations
- Include questions, rating scales, and hierarchy settings
- Managed by administrators through the admin panel

### Response Records (type: 'response')
- Store student feedback responses
- Include subject information, student hierarchy, and question responses
- Each response contains:
  - Campaign ID reference
  - Subject details (ID, name, code)
  - Student information (semester, branch, college)
  - Question responses with ratings and comments
  - Submission timestamp

## Navigation Flow

1. Academic Info Screen → Subject Feedback List Screen
2. Subject Feedback List Screen → Feedback Form Screen (for selected subject)
3. Feedback Form Screen → Submit feedback and return to list

## Features

- Subject-specific feedback collection
- Campaign-based feedback system
- Anonymous feedback submission
- Multi-question support with ratings and comments
- Responsive design for mobile and desktop
- Error handling and loading states
- Network connectivity awareness
