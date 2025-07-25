;; Experience Synthesis Integration Contract
;; Combines memories and learning from multiple consciousness instances

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-INVALID-INPUT (err u302))
(define-constant ERR-SYNTHESIS-FAILED (err u303))
(define-constant ERR-MEMORY-CONFLICT (err u304))

;; Data Variables
(define-data-var next-experience-id uint u1)
(define-data-var next-synthesis-id uint u1)
(define-data-var max-experiences-per-synthesis uint u100)

;; Data Maps
(define-map experience-records
  { experience-id: uint }
  {
    instance-id: uint,
    owner: principal,
    experience-type: (string-ascii 30),
    memory-hash: (buff 32),
    skill-data: (string-ascii 100),
    emotional-weight: uint,
    timestamp: uint,
    reality-context: uint,
    learning-value: uint
  }
)

(define-map synthesis-sessions
  { synthesis-id: uint }
  {
    owner: principal,
    participating-instances: (list 10 uint),
    experience-ids: (list 100 uint),
    synthesis-type: (string-ascii 30),
    status: (string-ascii 20),
    creation-block: uint,
    completion-block: uint
  }
)

(define-map synthesized-knowledge
  { synthesis-id: uint }
  {
    integrated-skills: (string-ascii 200),
    consolidated-memories: (buff 32),
    wisdom-gained: uint,
    personality-adjustments: (string-ascii 100),
    conflict-resolutions: uint,
    synthesis-quality: uint
  }
)

(define-map memory-conflicts
  { synthesis-id: uint, conflict-id: uint }
  {
    conflicting-experiences: (list 10 uint),
    conflict-type: (string-ascii 30),
    resolution-method: (string-ascii 50),
    resolution-status: (string-ascii 20),
    priority: uint
  }
)

;; Read-only functions
(define-read-only (get-experience-record (experience-id uint))
  (map-get? experience-records { experience-id: experience-id })
)

(define-read-only (get-synthesis-session (synthesis-id uint))
  (map-get? synthesis-sessions { synthesis-id: synthesis-id })
)

(define-read-only (get-synthesized-knowledge (synthesis-id uint))
  (map-get? synthesized-knowledge { synthesis-id: synthesis-id })
)

(define-read-only (get-memory-conflict (synthesis-id uint) (conflict-id uint))
  (map-get? memory-conflicts { synthesis-id: synthesis-id, conflict-id: conflict-id })
)

(define-read-only (calculate-synthesis-quality (synthesis-id uint))
  (let ((knowledge-data (map-get? synthesized-knowledge { synthesis-id: synthesis-id })))
    (match knowledge-data
      some-data (let (
        (base-quality (get synthesis-quality some-data))
        (wisdom-bonus (/ (get wisdom-gained some-data) u10))
        (conflict-penalty (* (get conflict-resolutions some-data) u5))
      )
        (if (>= base-quality conflict-penalty)
          (ok (+ (- base-quality conflict-penalty) wisdom-bonus))
          (ok u0)
        )
      )
      (ok u0)
    )
  )
)

;; Public functions
(define-public (record-experience (instance-id uint) (experience-type (string-ascii 30)) (memory-hash (buff 32)) (skill-data (string-ascii 100)) (emotional-weight uint) (reality-context uint) (learning-value uint))
  (let ((current-id (var-get next-experience-id)))
    (asserts! (> instance-id u0) ERR-INVALID-INPUT)
    (asserts! (and (>= emotional-weight u1) (<= emotional-weight u10)) ERR-INVALID-INPUT)
    (asserts! (and (>= learning-value u1) (<= learning-value u10)) ERR-INVALID-INPUT)

    (map-set experience-records
      { experience-id: current-id }
      {
        instance-id: instance-id,
        owner: tx-sender,
        experience-type: experience-type,
        memory-hash: memory-hash,
        skill-data: skill-data,
        emotional-weight: emotional-weight,
        timestamp: block-height,
        reality-context: reality-context,
        learning-value: learning-value
      }
    )

    (var-set next-experience-id (+ current-id u1))
    (ok current-id)
  )
)

(define-public (initiate-synthesis (participating-instances (list 10 uint)) (experience-ids (list 100 uint)) (synthesis-type (string-ascii 30)))
  (let ((current-id (var-get next-synthesis-id)))
    (asserts! (> (len participating-instances) u1) ERR-INVALID-INPUT)
    (asserts! (> (len experience-ids) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len experience-ids) (var-get max-experiences-per-synthesis)) ERR-INVALID-INPUT)

    ;; Verify ownership of all experiences
    (asserts! (fold check-experience-ownership experience-ids true) ERR-NOT-AUTHORIZED)

    (map-set synthesis-sessions
      { synthesis-id: current-id }
      {
        owner: tx-sender,
        participating-instances: participating-instances,
        experience-ids: experience-ids,
        synthesis-type: synthesis-type,
        status: "processing",
        creation-block: block-height,
        completion-block: u0
      }
    )

    ;; Initialize synthesis knowledge
    (map-set synthesized-knowledge
      { synthesis-id: current-id }
      {
        integrated-skills: "",
        consolidated-memories: 0x00,
        wisdom-gained: u0,
        personality-adjustments: "",
        conflict-resolutions: u0,
        synthesis-quality: u50
      }
    )

    (var-set next-synthesis-id (+ current-id u1))
    (ok current-id)
  )
)

(define-public (process-synthesis (synthesis-id uint) (integrated-skills (string-ascii 200)) (consolidated-memories (buff 32)) (wisdom-gained uint) (personality-adjustments (string-ascii 100)))
  (let ((session-data (unwrap! (map-get? synthesis-sessions { synthesis-id: synthesis-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner session-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status session-data) "processing") ERR-SYNTHESIS-FAILED)
    (asserts! (<= wisdom-gained u100) ERR-INVALID-INPUT)

    ;; Calculate synthesis quality based on inputs
    (let ((quality-score (+ u50 (/ wisdom-gained u2))))
      (map-set synthesized-knowledge
        { synthesis-id: synthesis-id }
        {
          integrated-skills: integrated-skills,
          consolidated-memories: consolidated-memories,
          wisdom-gained: wisdom-gained,
          personality-adjustments: personality-adjustments,
          conflict-resolutions: u0,
          synthesis-quality: quality-score
        }
      )
    )

    (ok true)
  )
)

(define-public (resolve-memory-conflict (synthesis-id uint) (conflict-id uint) (conflicting-experiences (list 10 uint)) (conflict-type (string-ascii 30)) (resolution-method (string-ascii 50)))
  (let ((session-data (unwrap! (map-get? synthesis-sessions { synthesis-id: synthesis-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner session-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len conflicting-experiences) u1) ERR-INVALID-INPUT)

    (map-set memory-conflicts
      { synthesis-id: synthesis-id, conflict-id: conflict-id }
      {
        conflicting-experiences: conflicting-experiences,
        conflict-type: conflict-type,
        resolution-method: resolution-method,
        resolution-status: "resolved",
        priority: (len conflicting-experiences)
      }
    )

    ;; Update conflict resolution count
    (let ((knowledge-data (unwrap! (map-get? synthesized-knowledge { synthesis-id: synthesis-id }) ERR-NOT-FOUND)))
      (map-set synthesized-knowledge
        { synthesis-id: synthesis-id }
        (merge knowledge-data { conflict-resolutions: (+ (get conflict-resolutions knowledge-data) u1) })
      )
    )

    (ok true)
  )
)

(define-public (complete-synthesis (synthesis-id uint))
  (let ((session-data (unwrap! (map-get? synthesis-sessions { synthesis-id: synthesis-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get owner session-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status session-data) "processing") ERR-SYNTHESIS-FAILED)

    (map-set synthesis-sessions
      { synthesis-id: synthesis-id }
      (merge session-data {
        status: "completed",
        completion-block: block-height
      })
    )

    (ok true)
  )
)

;; Private functions
(define-private (check-experience-ownership (experience-id uint) (acc bool))
  (if acc
    (let ((experience-data (map-get? experience-records { experience-id: experience-id })))
      (match experience-data
        some-exp (is-eq (get owner some-exp) tx-sender)
        false
      )
    )
    false
  )
)

(define-public (set-max-experiences-per-synthesis (new-max uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-max u0) ERR-INVALID-INPUT)
    (var-set max-experiences-per-synthesis new-max)
    (ok true)
  )
)
