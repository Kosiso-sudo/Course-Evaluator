;; DECENTRALIZED ACADEMIC COURSE EVALUATION SYSTEM SMART CONTRACT
;;
;; A blockchain-based platform for transparent, anonymous course evaluations
;; that enables students to provide feedback on their academic courses while
;; ensuring data integrity, preventing evaluation fraud, and maintaining
;; proper access controls. The system supports course management, student
;; enrollment tracking, and comprehensive evaluation analytics.

;; SYSTEM CONFIGURATION & CONSTANTS

;; Platform administrator (contract deployer)
(define-constant platform-administrator tx-sender)

;; Evaluation rating constraints
(define-constant min-allowed-rating u1)
(define-constant max-allowed-rating u5)

;; Maximum text lengths for user inputs
(define-constant max-course-name-length u100)
(define-constant max-feedback-text-length u500)

;; ERROR CODE DEFINITIONS

(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-COURSE-NOT-FOUND (err u101))
(define-constant ERR-DUPLICATE-COURSE-ID (err u102))
(define-constant ERR-INSUFFICIENT-PERMISSIONS (err u103))
(define-constant ERR-INVALID-RATING-VALUE (err u104))
(define-constant ERR-DUPLICATE-EVALUATION (err u105))
(define-constant ERR-STUDENT-NOT-ENROLLED (err u106))
(define-constant ERR-EVALUATIONS-DISABLED (err u107))
(define-constant ERR-INVALID-INPUT-FORMAT (err u108))
(define-constant ERR-INVALID-COURSE-ID (err u109))

;; CORE DATA STRUCTURES

;; Course registry - stores all course information
(define-map course-registry
  { course-id: uint }
  {
    course-title: (string-ascii 100),
    instructor-address: principal,
    evaluation-enabled: bool
  }
)

;; Student evaluation records - stores individual feedback entries
(define-map evaluation-records
  { course-id: uint, student-address: principal }
  {
    rating-score: uint,
    feedback-text: (string-utf8 500),
    submission-block: uint
  }
)

;; Student enrollment registry - tracks course enrollment
(define-map enrollment-registry
  { course-id: uint, student-address: principal }
  { enrolled-status: bool }
)

;; Course statistics - aggregated evaluation data
(define-map course-statistics
  { course-id: uint }
  {
    total-rating-points: uint,
    evaluation-count: uint
  }
)

;; Global course counter for unique ID generation
(define-data-var next-course-id uint u0)

;; ACCESS CONTROL FUNCTIONS

;; Check if caller has platform administration privileges
(define-read-only (is-platform-admin)
  (is-eq tx-sender platform-administrator)
)

;; Check if caller is the assigned instructor for a course
(define-read-only (is-course-instructor (course-id uint))
  (match (get-course-details course-id)
    course-info (is-eq tx-sender (get instructor-address course-info))
    false
  )
)

;; Check if caller can manage the specified course
(define-read-only (can-manage-course (course-id uint))
  (or 
    (is-platform-admin)
    (is-course-instructor course-id)
  )
)

;; INPUT VALIDATION HELPERS

;; Validate course title format and length
(define-read-only (is-valid-course-title (course-title (string-ascii 100)))
  (and 
    (> (len course-title) u0)
    (<= (len course-title) max-course-name-length)
  )
)

;; Validate feedback text format and length
(define-read-only (is-valid-feedback-text (feedback-text (string-utf8 500)))
  (and 
    (> (len feedback-text) u0)
    (<= (len feedback-text) max-feedback-text-length)
  )
)

;; Validate rating value within acceptable range
(define-read-only (is-valid-rating (rating-value uint))
  (and 
    (>= rating-value min-allowed-rating)
    (<= rating-value max-allowed-rating)
  )
)

;; Validate course ID is within valid range
(define-read-only (is-valid-course-id (course-id uint))
  (and 
    (> course-id u0)
    (<= course-id (var-get next-course-id))
  )
)

;; DATA RETRIEVAL FUNCTIONS

;; Retrieve complete course information by ID
(define-read-only (get-course-details (course-id uint))
  (map-get? course-registry { course-id: course-id })
)

;; Check if student is enrolled in a specific course
(define-read-only (is-student-enrolled (course-id uint) (student-address principal))
  (default-to 
    false
    (get enrolled-status 
         (map-get? enrollment-registry 
                   { course-id: course-id, 
                     student-address: student-address }))
  )
)

;; Retrieve student's evaluation for a course
(define-read-only (get-student-evaluation (course-id uint) (student-address principal))
  (map-get? evaluation-records 
    { course-id: course-id, 
      student-address: student-address })
)

;; Calculate average rating for a course
(define-read-only (calculate-course-average-rating (course-id uint))
  (match (map-get? course-statistics { course-id: course-id })
    stats-data 
      (let (
        (total-points (get total-rating-points stats-data))
        (total-evaluations (get evaluation-count stats-data))
      )
        (if (> total-evaluations u0)
          (/ total-points total-evaluations)
          u0
        )
      )
    u0
  )
)

;; Get total number of evaluations for a course
(define-read-only (get-course-evaluation-count (course-id uint))
  (default-to
    u0
    (get evaluation-count 
         (map-get? course-statistics { course-id: course-id }))
  )
)

;; Get current course ID counter value
(define-read-only (get-current-course-counter)
  (var-get next-course-id)
)

;; COURSE MANAGEMENT FUNCTIONS

;; Create a new course in the system
(define-public (create-new-course (course-title (string-ascii 100)))
  (let ((new-course-id (+ (var-get next-course-id) u1)))
    
    ;; Only platform administrators can create courses
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate course title meets requirements
    (asserts! (is-valid-course-title course-title) ERR-INVALID-INPUT-FORMAT)
    
    ;; Register new course in the system
    (map-set course-registry
      { course-id: new-course-id }
      {
        course-title: course-title,
        instructor-address: tx-sender,
        evaluation-enabled: true
      }
    )
    
    ;; Initialize course statistics
    (map-set course-statistics
      { course-id: new-course-id }
      {
        total-rating-points: u0,
        evaluation-count: u0
      }
    )
    
    ;; Update global course counter
    (var-set next-course-id new-course-id)
    
    ;; Return new course ID
    (ok new-course-id)
  )
)

;; Update instructor assignment for an existing course
(define-public (update-course-instructor (course-id uint) (new-instructor principal))
  (begin
    ;; Only platform administrators can reassign instructors
    (asserts! (is-platform-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    ;; Verify course exists and get course info
    (match (get-course-details course-id)
      course-info
        (begin
          ;; Update instructor assignment
          (map-set course-registry
            { course-id: course-id }
            (merge course-info
                   { instructor-address: new-instructor })
          )
          
          (ok true)
        )
      ERR-COURSE-NOT-FOUND
    )
  )
)

;; Toggle evaluation acceptance status for a course
(define-public (toggle-evaluation-status (course-id uint) (enabled-status bool))
  (begin
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    ;; Verify course exists and get course info
    (match (get-course-details course-id)
      course-info
        (begin
          ;; Verify caller has course management permissions
          (asserts! (can-manage-course course-id) ERR-INSUFFICIENT-PERMISSIONS)
          
          ;; Update evaluation acceptance status
          (map-set course-registry
            { course-id: course-id }
            (merge course-info 
                   { evaluation-enabled: enabled-status })
          )
          
          (ok true)
        )
      ERR-COURSE-NOT-FOUND
    )
  )
)

;; STUDENT ENROLLMENT FUNCTIONS

;; Enroll a student in a course for evaluation eligibility
(define-public (enroll-student (course-id uint) (target-student principal))
  (let (
    (student-to-enroll (if (is-eq target-student tx-sender) 
                          tx-sender 
                          target-student))
  )
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    ;; Verify course exists
    (asserts! (is-some (get-course-details course-id)) ERR-COURSE-NOT-FOUND)
    
    ;; Verify caller has course management permissions
    (asserts! (can-manage-course course-id) ERR-INSUFFICIENT-PERMISSIONS)
    
    ;; Register student enrollment
    (map-set enrollment-registry
      { course-id: course-id, 
        student-address: student-to-enroll }
      { enrolled-status: true }
    )
    
    (ok true)
  )
)

;; Remove student enrollment from a course
(define-public (unenroll-student (course-id uint) (target-student principal))
  (let (
    (student-to-unenroll (if (is-eq target-student tx-sender) 
                            tx-sender 
                            target-student))
  )
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    ;; Verify course exists
    (asserts! (is-some (get-course-details course-id)) ERR-COURSE-NOT-FOUND)
    
    ;; Verify caller has course management permissions
    (asserts! (can-manage-course course-id) ERR-INSUFFICIENT-PERMISSIONS)
    
    ;; Update student enrollment status
    (map-set enrollment-registry
      { course-id: course-id, 
        student-address: student-to-unenroll }
      { enrolled-status: false }
    )
    
    (ok true)
  )
)

;; EVALUATION SUBMISSION FUNCTIONS

;; Submit a course evaluation with rating and feedback
(define-public (submit-course-evaluation 
                (course-id uint) 
                (rating-score uint) 
                (feedback-text (string-utf8 500)))
  (let (
    (course-info (get-course-details course-id))
    (existing-evaluation (get-student-evaluation course-id tx-sender))
    (current-stats (map-get? course-statistics { course-id: course-id }))
  )
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    ;; Verify course exists in registry
    (asserts! (is-some course-info) ERR-COURSE-NOT-FOUND)
    
    ;; Verify course accepts new evaluations
    (asserts! (get evaluation-enabled (unwrap-panic course-info)) 
             ERR-EVALUATIONS-DISABLED)
    
    ;; Verify student enrollment eligibility
    (asserts! (is-student-enrolled course-id tx-sender) 
             ERR-STUDENT-NOT-ENROLLED)
    
    ;; Validate rating within acceptable range
    (asserts! (is-valid-rating rating-score) ERR-INVALID-RATING-VALUE)
    
    ;; Prevent duplicate evaluation submissions
    (asserts! (is-none existing-evaluation) ERR-DUPLICATE-EVALUATION)
    
    ;; Validate feedback text format
    (asserts! (is-valid-feedback-text feedback-text) ERR-INVALID-INPUT-FORMAT)
    
    ;; Store student evaluation
    (map-set evaluation-records
      { course-id: course-id, 
        student-address: tx-sender }
      {
        rating-score: rating-score,
        feedback-text: feedback-text,
        submission-block: block-height
      }
    )
    
    ;; Update course statistics
    (match current-stats
      existing-stats
        (map-set course-statistics
          { course-id: course-id }
          {
            total-rating-points: (+ (get total-rating-points existing-stats) rating-score),
            evaluation-count: (+ (get evaluation-count existing-stats) u1)
          }
        )
      ;; Initialize statistics if none exist
      (map-set course-statistics
        { course-id: course-id }
        {
          total-rating-points: rating-score,
          evaluation-count: u1
        }
      )
    )
    
    (ok true)
  )
)

;; ANALYTICS AND REPORTING FUNCTIONS

;; Get comprehensive course statistics
(define-read-only (get-course-analytics (course-id uint))
  (let (
    (course-info (get-course-details course-id))
    (stats-info (map-get? course-statistics { course-id: course-id }))
  )
    ;; Validate course ID is in valid range
    (asserts! (is-valid-course-id course-id) ERR-INVALID-COURSE-ID)
    
    (match course-info
      course-data
        (match stats-info
          stats-data
            (ok {
              course-title: (get course-title course-data),
              instructor: (get instructor-address course-data),
              evaluation-count: (get evaluation-count stats-data),
              average-rating: (calculate-course-average-rating course-id),
              total-rating-points: (get total-rating-points stats-data)
            })
          (ok {
            course-title: (get course-title course-data),
            instructor: (get instructor-address course-data),
            evaluation-count: u0,
            average-rating: u0,
            total-rating-points: u0
          })
        )
      ERR-COURSE-NOT-FOUND
    )
  )
)