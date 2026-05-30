;;; dired-clipboard-tests.el --- Tests for dired-clipboard -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Code:

(require 'ert)
(require 'dired-clipboard)

(ert-deftest dired-clipboard-copy-backends-skip-unavailable ()
  "File clipboard copy uses the first available successful backend."
  (let* ((calls nil)
         (dired-clipboard-file-clipboard-backends
          '(missing disabled failing ok later))
         (dired-clipboard-file-clipboard-backend-alist
          `((disabled
             :available ,(lambda (_operation _payload) nil)
             :copy ,(lambda (_payload)
                      (push 'disabled calls)
                      t))
            (failing
             :copy ,(lambda (_payload)
                      (push 'failing calls)
                      nil))
            (ok
             :copy ,(lambda (_payload)
                      (push 'ok calls)
                      t))
            (later
             :copy ,(lambda (_payload)
                      (push 'later calls)
                      t)))))
    (should (eq (dired-clipboard--copy-with-file-backends
                 '(:local-files ("/tmp/example")))
                'ok))
    (should (equal (nreverse calls) '(failing ok)))))

(ert-deftest dired-clipboard-files-from-clipboard-falls-back-after-missing-files ()
  "Paste falls through when a backend returns paths Emacs cannot see."
  (let* ((existing (make-temp-file "dired-clipboard-test"))
         (missing (concat existing "-missing"))
         (kill-ring (list existing))
         (kill-ring-yank-pointer kill-ring)
         (dired-clipboard-file-clipboard-backends '(backend))
         (dired-clipboard-file-clipboard-backend-alist
          (list (list 'backend :paste (lambda () (list missing))))))
    (unwind-protect
        (should (equal (dired-clipboard--files-from-clipboard)
                       (list existing)))
      (delete-file existing))))

(ert-deftest dired-clipboard-paste-backends-skip-missing-files ()
  "File clipboard paste tries the next backend when paths are not visible."
  (let* ((existing (make-temp-file "dired-clipboard-test"))
         (missing (concat existing "-missing"))
         (dired-clipboard-file-clipboard-backends '(first second)))
    (let ((dired-clipboard-file-clipboard-backend-alist
           (list (list 'first :paste (lambda () (list missing)))
                 (list 'second :paste (lambda () (list existing))))))
      (unwind-protect
          (should (equal (dired-clipboard--files-from-file-backends)
                         (list existing)))
        (delete-file existing)))))

(ert-deftest dired-clipboard-wayland-target-detects-mate ()
  "MATE desktops use Caja's copied-files MIME target."
  (let ((dired-clipboard-wayland-target 'auto)
        (process-environment
         (cons "XDG_CURRENT_DESKTOP=MATE" process-environment)))
    (should (eq (dired-clipboard--wayland-target) 'mate))
    (should (equal (dired-clipboard--wayland-mime-and-data
                    "copy\nfile:///tmp/example" "file:///tmp/example\r\n")
                   '("x-special/mate-copied-files" . "copy\nfile:///tmp/example")))))

(ert-deftest dired-clipboard-copied-files-supports-mate-target ()
  "MATE/Caja copied-files payloads are parsed and advertised."
  (let ((file (make-temp-file "dired-clipboard-test")))
    (unwind-protect
        (let* ((uri (dired-clipboard--file-to-uri file))
               (payload (concat "copy\n" uri)))
          (should (equal (dired-clipboard--parse-copied-files payload)
                         (list file)))
          (should (equal (dired-clipboard--parse-copied-files
                          (concat "x-special/mate-copied-files\n" payload))
                         (list file)))
          (should (equal (get-text-property
                          0 'x-special/mate-copied-files
                          (plist-get
                           (dired-clipboard--file-clipboard-payload
                            (list file))
                           :selection))
                         payload)))
      (delete-file file))))

(provide 'dired-clipboard-tests)

;;; dired-clipboard-tests.el ends here
