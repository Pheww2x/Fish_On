import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  final int rating;
  final double size;
  final Color? color;
  final bool interactive;
  final Function(int)? onRatingChanged;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.color,
    this.interactive = false,
    this.onRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return GestureDetector(
          onTap: interactive ? () => onRatingChanged?.call(i + 1) : null,
          child: Icon(
            i < rating ? Icons.star : Icons.star_border,
            size: size,
            color: color ?? (i < rating ? Colors.amber : Colors.grey),
          ),
        );
      }),
    );
  }
}

class RatingDialog extends StatefulWidget {
  final String fishermanName;
  final Future<void> Function(int rating, String review) onSubmit;

  const RatingDialog({
    super.key,
    required this.fishermanName,
    required this.onSubmit,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _rating = 5;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.star, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Rate ${widget.fishermanName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // Interactive Star Rating
            RatingStars(
              rating: _rating,
              size: 40,
              interactive: true,
              onRatingChanged: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _getRatingColor(_rating),
              ),
            ),
            const SizedBox(height: 20),

            // Review Text Field
            TextField(
              controller: _reviewController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF42A5F5),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  _isSubmitting
                      ? [Colors.grey, Colors.grey.shade600]
                      : [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed:
                _isSubmitting
                    ? null
                    : () async {
                      setState(() => _isSubmitting = true);

                      try {
                        await widget.onSubmit(
                          _rating,
                          _reviewController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        // Error handling is done in the parent widget
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSubmitting) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Rating',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Rate';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class EditRatingDialog extends StatefulWidget {
  final String fishermanName;
  final int currentRating;
  final String currentReview;
  final Future<void> Function(int rating, String review) onSubmit;

  const EditRatingDialog({
    super.key,
    required this.fishermanName,
    required this.currentRating,
    required this.currentReview,
    required this.onSubmit,
  });

  @override
  State<EditRatingDialog> createState() => _EditRatingDialogState();
}

class _EditRatingDialogState extends State<EditRatingDialog> {
  late int _rating;
  late TextEditingController _reviewController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.currentRating;
    _reviewController = TextEditingController(text: widget.currentReview);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Edit Rating for ${widget.fishermanName}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Update your experience rating',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // Interactive Star Rating
            RatingStars(
              rating: _rating,
              size: 40,
              interactive: true,
              onRatingChanged: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _getRatingText(_rating),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _getRatingColor(_rating),
              ),
            ),
            const SizedBox(height: 20),

            // Review Text Field
            TextField(
              controller: _reviewController,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Update your review (optional)',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF42A5F5),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors:
                  _isSubmitting
                      ? [Colors.grey, Colors.grey.shade600]
                      : [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextButton(
            onPressed:
                _isSubmitting
                    ? null
                    : () async {
                      setState(() => _isSubmitting = true);

                      try {
                        await widget.onSubmit(
                          _rating,
                          _reviewController.text.trim(),
                        );
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        // Error handling is done in the parent widget
                        if (mounted) {
                          setState(() => _isSubmitting = false);
                        }
                      }
                    },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isSubmitting) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  _isSubmitting ? 'Updating...' : 'Update Rating',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Rate';
    }
  }

  Color _getRatingColor(int rating) {
    switch (rating) {
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow[700]!;
      case 4:
        return Colors.lightGreen;
      case 5:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
