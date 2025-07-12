# Decentralized Academic Course Evaluation System

A blockchain-based platform for transparent, anonymous course evaluations that enables students to provide feedback on their academic courses while ensuring data integrity, preventing evaluation fraud, and maintaining proper access controls.

## Overview

This smart contract provides a complete solution for managing academic course evaluations on the blockchain. It supports course management, student enrollment tracking, and comprehensive evaluation analytics while maintaining transparency and preventing fraud.

## Features

- **Course Management**: Create and manage academic courses
- **Student Enrollment**: Track student enrollment for evaluation eligibility
- **Secure Evaluations**: Submit anonymous course evaluations with ratings and feedback
- **Access Control**: Role-based permissions for administrators and instructors
- **Analytics**: Comprehensive course statistics and evaluation analytics
- **Fraud Prevention**: Prevents duplicate evaluations and ensures data integrity

## Architecture

### Core Components

1. **Course Registry**: Stores all course information including titles, instructors, and evaluation status
2. **Evaluation Records**: Stores individual student feedback entries with ratings and comments
3. **Enrollment Registry**: Tracks which students are enrolled in which courses
4. **Course Statistics**: Aggregated evaluation data for analytics

### Access Control

- **Platform Administrator**: Full system access (contract deployer)
- **Course Instructors**: Can manage their assigned courses and enrollments
- **Students**: Can submit evaluations for enrolled courses

## Constants and Configuration

```clarity
;; Rating constraints
min-allowed-rating: 1
max-allowed-rating: 5

;; Text length limits
max-course-name-length: 100 characters
max-feedback-text-length: 500 characters
```

## Error Codes

| Code | Description |
|------|-------------|
| 100 | Unauthorized Access |
| 101 | Course Not Found |
| 102 | Duplicate Course ID |
| 103 | Insufficient Permissions |
| 104 | Invalid Rating Value |
| 105 | Duplicate Evaluation |
| 106 | Student Not Enrolled |
| 107 | Evaluations Disabled |
| 108 | Invalid Input Format |

## Core Functions

### Course Management

#### `create-new-course`
Creates a new course in the system.
- **Access**: Platform Administrator only
- **Parameters**: `course-title` (string-ascii 100)
- **Returns**: New course ID

#### `update-course-instructor`
Updates the instructor assignment for an existing course.
- **Access**: Platform Administrator only
- **Parameters**: `course-id` (uint), `new-instructor` (principal)

#### `toggle-evaluation-status`
Enables or disables evaluation acceptance for a course.
- **Access**: Course managers (admin or instructor)
- **Parameters**: `course-id` (uint), `enabled-status` (bool)

### Student Enrollment

#### `enroll-student`
Enrolls a student in a course for evaluation eligibility.
- **Access**: Course managers (admin or instructor)
- **Parameters**: `course-id` (uint), `target-student` (principal)

#### `unenroll-student`
Removes student enrollment from a course.
- **Access**: Course managers (admin or instructor)
- **Parameters**: `course-id` (uint), `target-student` (principal)

### Evaluation Submission

#### `submit-course-evaluation`
Submits a course evaluation with rating and feedback.
- **Access**: Enrolled students only
- **Parameters**: 
  - `course-id` (uint)
  - `rating-score` (uint, 1-5)
  - `feedback-text` (string-utf8 500)
- **Restrictions**: One evaluation per student per course

### Data Retrieval

#### `get-course-details`
Retrieves complete course information by ID.
- **Parameters**: `course-id` (uint)
- **Returns**: Course details or none

#### `get-course-analytics`
Gets comprehensive course statistics including average rating and evaluation count.
- **Parameters**: `course-id` (uint)
- **Returns**: Course analytics data

#### `calculate-course-average-rating`
Calculates the average rating for a course.
- **Parameters**: `course-id` (uint)
- **Returns**: Average rating (uint)

#### `is-student-enrolled`
Checks if a student is enrolled in a specific course.
- **Parameters**: `course-id` (uint), `student-address` (principal)
- **Returns**: Boolean enrollment status

## Usage Examples

### Creating a Course (Administrator)
```clarity
(contract-call? .course-evaluation create-new-course "Introduction to Computer Science")
```

### Enrolling a Student (Instructor/Admin)
```clarity
(contract-call? .course-evaluation enroll-student u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Submitting an Evaluation (Student)
```clarity
(contract-call? .course-evaluation submit-course-evaluation 
  u1 
  u4 
  u"Great course! The instructor was very helpful and the material was well-structured.")
```

### Getting Course Analytics
```clarity
(contract-call? .course-evaluation get-course-analytics u1)
```

## Security Features

1. **Role-Based Access Control**: Different permission levels for administrators, instructors, and students
2. **Duplicate Prevention**: Prevents students from submitting multiple evaluations for the same course
3. **Input Validation**: Validates all input parameters for format and length
4. **Enrollment Verification**: Ensures only enrolled students can submit evaluations
5. **Evaluation Status Control**: Instructors can disable evaluations when needed

## Data Privacy

- Student evaluations are stored with their principal address but can be considered pseudonymous
- Feedback text is stored on-chain but associated with blockchain addresses rather than real identities
- The system maintains transparency while protecting student privacy through blockchain pseudonymity