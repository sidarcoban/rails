# encoding: utf-8
require 'abstract_unit'
require 'set'

require 'action_dispatch'
require 'active_support/time'

require 'mailers/base_mailer'
require 'mailers/proc_mailer'
require 'mailers/asset_mailer'

class BaseTest < ActiveSupport::TestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  setup do
    @original_delivery_method = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    @original_asset_host = ActionMailer::Base.asset_host
    @original_assets_dir = ActionMailer::Base.assets_dir
  end

  teardown do
    ActionMailer::Base.asset_host = @original_asset_host
    ActionMailer::Base.assets_dir = @original_assets_dir
    BaseMailer.deliveries.clear
    ActionMailer::Base.delivery_method = @original_delivery_method
  end

  test "method call to mail does not raise error" do
    assert_nothing_raised { BaseMailer.welcome }
  end

  # Basic mail usage without block
  test "mail() should set the headers of the mail message" do
    email = BaseMailer.welcome
    assert_equal(['system@test.lindsaar.net'],    email.to)
    assert_equal(['jose@test.plataformatec.com'], email.from)
    assert_equal('The first email on new API!',   email.subject)
  end

  test "mail() with from overwrites the class level default" do
    email = BaseMailer.welcome(from: 'someone@example.com',
                               to:   'another@example.org')
    assert_equal(['someone@example.com'], email.from)
    assert_equal(['another@example.org'], email.to)
  end

  test "mail() with bcc, cc, content_type, charset, mime_version, reply_to and date" do
    time  = Time.now.beginning_of_day.to_datetime
    email = BaseMailer.welcome(bcc: 'bcc@test.lindsaar.net',
                               cc: 'cc@test.lindsaar.net',
                               content_type: 'multipart/mixed',
                               charset: 'iso-8559-1',
                               mime_version: '2.0',
                               reply_to: 'reply-to@test.lindsaar.net',
                               date: time)
    assert_equal(['bcc@test.lindsaar.net'],             email.bcc)
    assert_equal(['cc@test.lindsaar.net'],              email.cc)
    assert_equal('multipart/mixed; charset=iso-8559-1', email.content_type)
    assert_equal('iso-8559-1',                          email.charset)
    assert_equal('2.0',                                 email.mime_version)
    assert_equal(['reply-to@test.lindsaar.net'],        email.reply_to)
    assert_equal(time,                                  email.date)
  end

  test "mail() renders the template using the method being processed" do
    email = BaseMailer.welcome
    assert_equal("Welcome", email.body.encoded)
  end

  test "can pass in :body to the mail method hash" do
    email = BaseMailer.welcome(body: "Hello there")
    assert_equal("text/plain", email.mime_type)
    assert_equal("Hello there", email.body.encoded)
  end

  test "should set template content type if mail has only one part" do
    mail = BaseMailer.html_only
    assert_equal('text/html', mail.mime_type)
    mail = BaseMailer.plain_text_only
    assert_equal('text/plain', mail.mime_type)
  end

  # Custom headers
  test "custom headers" do
    email = BaseMailer.welcome
    assert_equal("Not SPAM", email['X-SPAM'].decoded)
  end

  test "can pass random headers in as a hash to mail" do
    hash = {'X-Special-Domain-Specific-Header' => "SecretValue",
            'In-Reply-To' => '1234@mikel.me.com' }
    mail = BaseMailer.welcome(hash)
    assert_equal('SecretValue', mail['X-Special-Domain-Specific-Header'].decoded)
    assert_equal('1234@mikel.me.com', mail['In-Reply-To'].decoded)
  end

  test "can pass random headers in as a hash to headers" do
    hash = {'X-Special-Domain-Specific-Header' => "SecretValue",
            'In-Reply-To' => '1234@mikel.me.com' }
    mail = BaseMailer.welcome_with_headers(hash)
    assert_equal('SecretValue', mail['X-Special-Domain-Specific-Header'].decoded)
    assert_equal('1234@mikel.me.com', mail['In-Reply-To'].decoded)
  end

  # Attachments
  test "attachment with content" do
    email = BaseMailer.attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.pdf', email.attachments[0].filename)
    assert_equal('This is test File content', email.attachments['invoice.pdf'].decoded)
  end

  test "attachment gets content type from filename" do
    email = BaseMailer.attachment_with_content
    assert_equal('invoice.pdf', email.attachments[0].filename)
    assert_equal('application/pdf', email.attachments[0].mime_type)
  end

  test "attachment with hash" do
    email = BaseMailer.attachment_with_hash
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.jpg', email.attachments[0].filename)
    expected = "\312\213\254\232)b"
    expected.force_encoding(Encoding::BINARY)
    assert_equal expected, email.attachments['invoice.jpg'].decoded
  end

  test "attachment with hash using default mail encoding" do
    email = BaseMailer.attachment_with_hash_default_encoding
    assert_equal(1, email.attachments.length)
    assert_equal('invoice.jpg', email.attachments[0].filename)
    expected = "\312\213\254\232)b"
    expected.force_encoding(Encoding::BINARY)
    assert_equal expected, email.attachments['invoice.jpg'].decoded
  end

  test "sets mime type to multipart/mixed when attachment is included" do
    email = BaseMailer.attachment_with_content
    assert_equal(1, email.attachments.length)
    assert_equal("multipart/mixed", email.mime_type)
  end

  test "adds the rendered template as part" do
    email = BaseMailer.attachment_with_content
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/html", email.parts[0].mime_type)
    assert_equal("Attachment with content", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  test "adds the given :body as part" do
    email = BaseMailer.attachment_with_content(body: "I'm the eggman")
    assert_equal(2, email.parts.length)
    assert_equal("multipart/mixed", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("I'm the eggman", email.parts[0].body.encoded)
    assert_equal("application/pdf", email.parts[1].mime_type)
    assert_equal("VGhpcyBpcyB0ZXN0IEZpbGUgY29udGVudA==\r\n", email.parts[1].body.encoded)
  end

  test "can embed an inline attachment" do
    email = BaseMailer.inline_attachment
    # Need to call #encoded to force the JIT sort on parts
    email.encoded
    assert_equal(2, email.parts.length)
    assert_equal("multipart/related", email.mime_type)
    assert_equal("multipart/alternative", email.parts[0].mime_type)
    assert_equal("text/plain", email.parts[0].parts[0].mime_type)
    assert_equal("text/html",  email.parts[0].parts[1].mime_type)
    assert_equal("logo.png", email.parts[1].filename)
  end

  # Defaults values
  test "uses default charset from class" do
    with_default BaseMailer, charset: "US-ASCII" do
      email = BaseMailer.welcome
      assert_equal("US-ASCII", email.charset)

      email = BaseMailer.welcome(charset: "iso-8559-1")
      assert_equal("iso-8559-1", email.charset)
    end
  end

  test "uses default content type from class" do
    with_default BaseMailer, content_type: "text/html" do
      email = BaseMailer.welcome
      assert_equal("text/html", email.mime_type)

      email = BaseMailer.welcome(content_type: "text/plain")
      assert_equal("text/plain", email.mime_type)
    end
  end

  test "uses default mime version from class" do
    with_default BaseMailer, mime_version: "2.0" do
      email = BaseMailer.welcome
      assert_equal("2.0", email.mime_version)

      email = BaseMailer.welcome(mime_version: "1.0")
      assert_equal("1.0", email.mime_version)
    end
  end

  test "uses random default headers from class" do
    with_default BaseMailer, "X-Custom" => "Custom" do
      email = BaseMailer.welcome
      assert_equal("Custom", email["X-Custom"].decoded)
    end
  end

  test "subject gets default from I18n" do
    with_default BaseMailer, subject: nil do
      email = BaseMailer.welcome(subject: nil)
      assert_equal "Welcome", email.subject

      with_translation 'en', base_mailer: {welcome: {subject: "New Subject!"}} do
        email = BaseMailer.welcome(subject: nil)
        assert_equal "New Subject!", email.subject
      end
    end
  end

  test 'default subject can have interpolations' do
    with_translation 'en', base_mailer: {with_subject_interpolations: {subject: 'Will the real %{rapper_or_impersonator} please stand up?'}} do
      email = BaseMailer.with_subject_interpolations
      assert_equal 'Will the real Slim Shady please stand up?', email.subject
    end
  end

  test "translations are scoped properly" do
    with_translation 'en', base_mailer: {email_with_translations: {greet_user: "Hello %{name}!"}} do
      email = BaseMailer.email_with_translations
      assert_equal 'Hello lifo!', email.body.encoded
    end
  end

  test "adding attachments after mail was called raises exception" do
    class LateAttachmentMailer < ActionMailer::Base
      def welcome
        mail body: "yay", from: "welcome@example.com", to: "to@example.com"
        attachments['invoice.pdf'] = 'This is test File content'
      end
    end

    e = assert_raises(RuntimeError) { LateAttachmentMailer.welcome.message }
    assert_match(/Can't add attachments after `mail` was called./, e.message)
  end

  test "adding inline attachments after mail was called raises exception" do
    class LateInlineAttachmentMailer < ActionMailer::Base
      def welcome
        mail body: "yay", from: "welcome@example.com", to: "to@example.com"
        attachments.inline['invoice.pdf'] = 'This is test File content'
      end
    end

    e = assert_raises(RuntimeError) { LateInlineAttachmentMailer.welcome.message }
    assert_match(/Can't add attachments after `mail` was called./, e.message)
  end

  test "adding inline attachments while rendering mail works" do
    class LateInlineAttachmentMailer < ActionMailer::Base
      def on_render
        mail from: "welcome@example.com", to: "to@example.com"
      end
    end

    mail = LateInlineAttachmentMailer.on_render
    assert_nothing_raised { mail.message }

    assert_equal ["image/jpeg; filename=controller_attachments.jpg",
                  "image/jpeg; filename=attachments.jpg"], mail.attachments.inline.map {|a| a['Content-Type'].to_s }
  end

  test "accessing attachments works after mail was called" do
    class LateAttachmentAccessorMailer < ActionMailer::Base
      def welcome
        attachments['invoice.pdf'] = 'This is test File content'
        mail body: "yay", from: "welcome@example.com", to: "to@example.com"

        unless attachments.map(&:filename) == ["invoice.pdf"]
          raise Minitest::Assertion, "Should allow access to attachments"
        end
      end
    end

    assert_nothing_raised { LateAttachmentAccessorMailer.welcome }
  end

  # Implicit multipart
  test "implicit multipart" do
    email = BaseMailer.implicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].body.encoded)
  end

  test "implicit multipart with sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, parts_order: order do
      email = BaseMailer.implicit_multipart
      assert_equal("text/html",  email.parts[0].mime_type)
      assert_equal("text/plain", email.parts[1].mime_type)

      email = BaseMailer.implicit_multipart(parts_order: order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  test "implicit multipart with attachments creates nested parts" do
    email = BaseMailer.implicit_multipart(attachments: true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternative", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Implicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Implicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "implicit multipart with attachments and sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, parts_order: order do
      email = BaseMailer.implicit_multipart(attachments: true)
      assert_equal("application/pdf", email.parts[0].mime_type)
      assert_equal("multipart/alternative", email.parts[1].mime_type)
      assert_equal("text/plain", email.parts[1].parts[1].mime_type)
      assert_equal("text/html", email.parts[1].parts[0].mime_type)
    end
  end

  test "implicit multipart with default locale" do
    email = BaseMailer.implicit_with_locale
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("Implicit with locale TEXT", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("Implicit with locale EN HTML", email.parts[1].body.encoded)
  end

  test "implicit multipart with other locale" do
    swap I18n, locale: :pl do
      email = BaseMailer.implicit_with_locale
      assert_equal(2, email.parts.size)
      assert_equal("multipart/alternative", email.mime_type)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("Implicit with locale PL TEXT", email.parts[0].body.encoded)
      assert_equal("text/html", email.parts[1].mime_type)
      assert_equal("Implicit with locale EN HTML", email.parts[1].body.encoded)
    end
  end

  test "implicit multipart with fallback locale" do
    fallback_backend = Class.new(I18n::Backend::Simple) do
      include I18n::Backend::Fallbacks
    end

    begin
      backend = I18n.backend
      I18n.backend = fallback_backend.new
      I18n.fallbacks[:"de-AT"] = [:de]

      swap I18n, locale: 'de-AT' do
        email = BaseMailer.implicit_with_locale
        assert_equal(2, email.parts.size)
        assert_equal("multipart/alternative", email.mime_type)
        assert_equal("text/plain", email.parts[0].mime_type)
        assert_equal("Implicit with locale DE-AT TEXT", email.parts[0].body.encoded)
        assert_equal("text/html", email.parts[1].mime_type)
        assert_equal("Implicit with locale DE HTML", email.parts[1].body.encoded)
      end
    ensure
      I18n.backend = backend
    end
  end


  test "implicit multipart with several view paths uses the first one with template" do
    old = BaseMailer.view_paths
    begin
      BaseMailer.view_paths = [File.join(FIXTURE_LOAD_PATH, "another.path")] + old.dup
      email = BaseMailer.welcome
      assert_equal("Welcome from another path", email.body.encoded)
    ensure
      BaseMailer.view_paths = old
    end
  end

  test "implicit multipart with inexistent templates uses the next view path" do
    old = BaseMailer.view_paths
    begin
      BaseMailer.view_paths = [File.join(FIXTURE_LOAD_PATH, "unknown")] + old.dup
      email = BaseMailer.welcome
      assert_equal("Welcome", email.body.encoded)
    ensure
      BaseMailer.view_paths = old
    end
  end

  # Explicit multipart
  test "explicit multipart" do
    email = BaseMailer.explicit_multipart
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].body.encoded)
  end

  test "explicit multipart have a boundary" do
    mail = BaseMailer.explicit_multipart
    assert_not_nil(mail.content_type_parameters[:boundary])
  end

  test "explicit multipart with attachments creates nested parts" do
    email = BaseMailer.explicit_multipart(attachments: true)
    assert_equal("application/pdf", email.parts[0].mime_type)
    assert_equal("multipart/alternative", email.parts[1].mime_type)
    assert_equal("text/plain", email.parts[1].parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart", email.parts[1].parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].parts[1].mime_type)
    assert_equal("HTML Explicit Multipart", email.parts[1].parts[1].body.encoded)
  end

  test "explicit multipart with templates" do
    email = BaseMailer.explicit_multipart_templates
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("TEXT Explicit Multipart Templates", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("HTML Explicit Multipart Templates", email.parts[1].body.encoded)
  end

  test "explicit multipart with format.any" do
    email = BaseMailer.explicit_multipart_with_any
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("Format with any!", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("Format with any!", email.parts[1].body.encoded)
  end

  test "explicit multipart with format(Hash)" do
    email = BaseMailer.explicit_multipart_with_options(true)
    email.ready_to_send!
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("base64", email.parts[0].content_transfer_encoding)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("7bit", email.parts[1].content_transfer_encoding)
  end

  test "explicit multipart with one part is rendered as body and options are merged" do
    email = BaseMailer.explicit_multipart_with_options
    assert_equal(0, email.parts.size)
    assert_equal("text/plain", email.mime_type)
    assert_equal("base64", email.content_transfer_encoding)
  end

  test "explicit multipart with one template has the expected format" do
    email = BaseMailer.explicit_multipart_with_one_template
    assert_equal(2, email.parts.size)
    assert_equal("multipart/alternative", email.mime_type)
    assert_equal("text/plain", email.parts[0].mime_type)
    assert_equal("[:text]", email.parts[0].body.encoded)
    assert_equal("text/html", email.parts[1].mime_type)
    assert_equal("[:html]", email.parts[1].body.encoded)
  end

  test "explicit multipart with sort order" do
    order = ["text/html", "text/plain"]
    with_default BaseMailer, parts_order: order do
      email = BaseMailer.explicit_multipart
      assert_equal("text/html",  email.parts[0].mime_type)
      assert_equal("text/plain", email.parts[1].mime_type)

      email = BaseMailer.explicit_multipart(parts_order: order.reverse)
      assert_equal("text/plain", email.parts[0].mime_type)
      assert_equal("text/html",  email.parts[1].mime_type)
    end
  end

  # Class level API with method missing
  test "should respond to action methods" do
    assert_respond_to BaseMailer, :welcome
    assert_respond_to BaseMailer, :implicit_multipart
    assert !BaseMailer.respond_to?(:mail)
    assert !BaseMailer.respond_to?(:headers)
  end

  test "calling just the action should return the generated mail object" do
    email = BaseMailer.welcome
    assert_equal(0, BaseMailer.deliveries.length)
    assert_equal('The first email on new API!', email.subject)
  end

  test "calling deliver on the action should deliver the mail object" do
    BaseMailer.expects(:deliver_mail).once
    mail = BaseMailer.welcome.deliver_now
    assert_equal 'The first email on new API!', mail.subject
  end

  test "calling deliver on the action should increment the deliveries collection if using the test mailer" do
    BaseMailer.welcome.deliver_now
    assert_equal(1, BaseMailer.deliveries.length)
  end

  test "calling deliver, ActionMailer should yield back to mail to let it call :do_delivery on itself" do
    mail = Mail::Message.new
    mail.expects(:do_delivery).once
    BaseMailer.expects(:welcome).returns(mail)
    BaseMailer.welcome.deliver
  end

  # Rendering
  test "you can specify a different template for implicit render" do
    mail = BaseMailer.implicit_different_template('implicit_multipart').deliver_now
    assert_equal("HTML Implicit Multipart", mail.html_part.body.decoded)
    assert_equal("TEXT Implicit Multipart", mail.text_part.body.decoded)
  end

  test "should raise if missing template in implicit render" do
    assert_raises ActionView::MissingTemplate do
      BaseMailer.implicit_different_template('missing_template').deliver_now
    end
    assert_equal(0, BaseMailer.deliveries.length)
  end

  test "you can specify a different template for explicit render" do
    mail = BaseMailer.explicit_different_template('explicit_multipart_templates').deliver_now
    assert_equal("HTML Explicit Multipart Templates", mail.html_part.body.decoded)
    assert_equal("TEXT Explicit Multipart Templates", mail.text_part.body.decoded)
  end

  test "you can specify a different layout" do
    mail = BaseMailer.different_layout('different_layout').deliver_now
    assert_equal("HTML -- HTML", mail.html_part.body.decoded)
    assert_equal("PLAIN -- PLAIN", mail.text_part.body.decoded)
  end

  test "you can specify the template path for implicit lookup" do
    mail = BaseMailer.welcome_from_another_path('another.path/base_mailer').deliver_now
    assert_equal("Welcome from another path", mail.body.encoded)

    mail = BaseMailer.welcome_from_another_path(['unknown/invalid', 'another.path/base_mailer']).deliver_now
    assert_equal("Welcome from another path", mail.body.encoded)
  end

  test "assets tags should use ActionMailer's asset_host settings" do
    ActionMailer::Base.config.asset_host = "http://global.com"
    ActionMailer::Base.config.assets_dir = "global/"

    mail = AssetMailer.welcome

    assert_dom_equal(%{<img alt="Dummy" src="http://global.com/images/dummy.png" />}, mail.body.to_s.strip)
  end

  test "assets tags should use a Mailer's asset_host settings when available" do
    ActionMailer::Base.config.asset_host = "http://global.com"
    ActionMailer::Base.config.assets_dir = "global/"

    TempAssetMailer = Class.new(AssetMailer) do
      self.mailer_name = "asset_mailer"
      self.asset_host = "http://local.com"
    end

    mail = TempAssetMailer.welcome

    assert_dom_equal(%{<img alt="Dummy" src="http://local.com/images/dummy.png" />}, mail.body.to_s.strip)
  end

  test 'the view is not rendered when mail was never called' do
    mail = BaseMailer.without_mail_call
    assert_equal('', mail.body.to_s.strip)
    mail.deliver_now
  end

  test 'the return value of mailer methods is not relevant' do
    mail = BaseMailer.with_nil_as_return_value
    assert_equal('Welcome', mail.body.to_s.strip)
    mail.deliver_now
  end

  # Before and After hooks

  class MyObserver
    def self.delivered_email(mail)
    end
  end

  class MySecondObserver
    def self.delivered_email(mail)
    end
  end

  test "you can register an observer to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer(MyObserver)
      mail = BaseMailer.welcome
      MyObserver.expects(:delivered_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register an observer using its stringified name to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer("BaseTest::MyObserver")
      mail = BaseMailer.welcome
      MyObserver.expects(:delivered_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register an observer using its symbolized underscored name to the mail object that gets informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observer(:"base_test/my_observer")
      mail = BaseMailer.welcome
      MyObserver.expects(:delivered_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register multiple observers to the mail object that both get informed on email delivery" do
    mail_side_effects do
      ActionMailer::Base.register_observers("BaseTest::MyObserver", MySecondObserver)
      mail = BaseMailer.welcome
      MyObserver.expects(:delivered_email).with(mail)
      MySecondObserver.expects(:delivered_email).with(mail)
      mail.deliver_now
    end
  end

  class MyInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  class MySecondInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  test "you can register an interceptor to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor(MyInterceptor)
      mail = BaseMailer.welcome
      MyInterceptor.expects(:delivering_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register an interceptor using its stringified name to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor("BaseTest::MyInterceptor")
      mail = BaseMailer.welcome
      MyInterceptor.expects(:delivering_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register an interceptor using its symbolized underscored name to the mail object that gets passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptor(:"base_test/my_interceptor")
      mail = BaseMailer.welcome
      MyInterceptor.expects(:delivering_email).with(mail)
      mail.deliver_now
    end
  end

  test "you can register multiple interceptors to the mail object that both get passed the mail object before delivery" do
    mail_side_effects do
      ActionMailer::Base.register_interceptors("BaseTest::MyInterceptor", MySecondInterceptor)
      mail = BaseMailer.welcome
      MyInterceptor.expects(:delivering_email).with(mail)
      MySecondInterceptor.expects(:delivering_email).with(mail)
      mail.deliver_now
    end
  end

  test "being able to put proc's into the defaults hash and they get evaluated on mail sending" do
    mail1 = ProcMailer.welcome['X-Proc-Method']
    yesterday = 1.day.ago
    Time.stubs(:now).returns(yesterday)
    mail2 = ProcMailer.welcome['X-Proc-Method']
    assert(mail1.to_s.to_i > mail2.to_s.to_i)
  end

  test 'default values which have to_proc (e.g. symbols) should not be considered procs' do
    assert(ProcMailer.welcome['x-has-to-proc'].to_s == 'symbol')
  end

  test "we can call other defined methods on the class as needed" do
    mail = ProcMailer.welcome
    assert_equal("Thanks for signing up this afternoon", mail.subject)
  end

  test "modifying the mail message with a before_action" do
    class BeforeActionMailer < ActionMailer::Base
      before_action :add_special_header!

      def welcome ; mail ; end

      private
      def add_special_header!
        headers('X-Special-Header' => 'Wow, so special')
      end
    end

    assert_equal('Wow, so special', BeforeActionMailer.welcome['X-Special-Header'].to_s)
  end

  test "modifying the mail message with an after_action" do
    class AfterActionMailer < ActionMailer::Base
      after_action :add_special_header!

      def welcome ; mail ; end

      private
      def add_special_header!
        headers('X-Special-Header' => 'Testing')
      end
    end

    assert_equal('Testing', AfterActionMailer.welcome['X-Special-Header'].to_s)
  end

  test "adding an inline attachment using a before_action" do
    class DefaultInlineAttachmentMailer < ActionMailer::Base
      before_action :add_inline_attachment!

      def welcome ; mail ; end

      private
      def add_inline_attachment!
        attachments.inline["footer.jpg"] = 'hey there'
      end
    end

    mail = DefaultInlineAttachmentMailer.welcome
    assert_equal('image/jpeg; filename=footer.jpg', mail.attachments.inline.first['Content-Type'].to_s)
  end

  test "action methods should be refreshed after defining new method" do
    class FooMailer < ActionMailer::Base
      # this triggers action_methods
      self.respond_to?(:foo)

      def notify
      end
    end

    assert_equal Set.new(["notify"]), FooMailer.action_methods
  end

  test "mailer can be anonymous" do
    mailer = Class.new(ActionMailer::Base) do
      def welcome
        mail
      end
    end

    assert_equal "anonymous", mailer.mailer_name

    assert_equal "Welcome", mailer.welcome.subject
    assert_equal "Anonymous mailer body", mailer.welcome.body.encoded.strip
  end

  test "default_from can be set" do
    class DefaultFromMailer < ActionMailer::Base
      default to: 'system@test.lindsaar.net'
      self.default_options = {from: "robert.pankowecki@gmail.com"}

      def welcome
        mail(subject: "subject", body: "hello world")
      end
    end

    assert_equal ["robert.pankowecki@gmail.com"], DefaultFromMailer.welcome.from
  end

  test "mail() without arguments serves as getter for the current mail message" do
    class MailerWithCallback < ActionMailer::Base
      after_action :a_callback

      def welcome
        headers('X-Special-Header' => 'special indeed!')
        mail subject: "subject", body: "hello world", to: ["joe@example.com"]
      end

      def a_callback
        mail.to << "jane@example.com"
      end
    end

    mail = MailerWithCallback.welcome
    assert_equal "subject", mail.subject
    assert_equal ["joe@example.com", "jane@example.com"], mail.to
    assert_equal "hello world", mail.body.encoded.strip
    assert_equal "special indeed!", mail["X-Special-Header"].to_s
  end

  protected

    # Execute the block setting the given values and restoring old values after
    # the block is executed.
    def swap(klass, new_values)
      old_values = {}
      new_values.each do |key, value|
        old_values[key] = klass.send key
        klass.send :"#{key}=", value
      end
      yield
    ensure
      old_values.each do |key, value|
        klass.send :"#{key}=", value
      end
    end

    def with_default(klass, new_values)
      old = klass.default_params
      klass.default(new_values)
      yield
    ensure
      klass.default_params = old
    end

    # A simple hack to restore the observers and interceptors for Mail, as it
    # does not have an unregister API yet.
    def mail_side_effects
      old_observers = Mail.class_variable_get(:@@delivery_notification_observers)
      old_delivery_interceptors = Mail.class_variable_get(:@@delivery_interceptors)
      yield
    ensure
      Mail.class_variable_set(:@@delivery_notification_observers, old_observers)
      Mail.class_variable_set(:@@delivery_interceptors, old_delivery_interceptors)
    end

    def with_translation(locale, data)
      I18n.backend.store_translations(locale, data)
      yield
    ensure
      I18n.backend.reload!
    end
end

class BasePreviewInterceptorsTest < ActiveSupport::TestCase
  teardown do
    ActionMailer::Base.preview_interceptors.clear
  end

  class BaseMailerPreview < ActionMailer::Preview
    def welcome
      BaseMailer.welcome
    end
  end

  class MyInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  class MySecondInterceptor
    def self.delivering_email(mail); end
    def self.previewing_email(mail); end
  end

  test "you can register a preview interceptor to the mail object that gets passed the mail object before previewing" do
    ActionMailer::Base.register_preview_interceptor(MyInterceptor)
    mail = BaseMailer.welcome
    BaseMailerPreview.any_instance.stubs(:welcome).returns(mail)
    MyInterceptor.expects(:previewing_email).with(mail)
    BaseMailerPreview.call(:welcome)
  end

  test "you can register a preview interceptor using its stringified name to the mail object that gets passed the mail object before previewing" do
    ActionMailer::Base.register_preview_interceptor("BasePreviewInterceptorsTest::MyInterceptor")
    mail = BaseMailer.welcome
    BaseMailerPreview.any_instance.stubs(:welcome).returns(mail)
    MyInterceptor.expects(:previewing_email).with(mail)
    BaseMailerPreview.call(:welcome)
  end

  test "you can register an interceptor using its symbolized underscored name to the mail object that gets passed the mail object before previewing" do
    ActionMailer::Base.register_preview_interceptor(:"base_preview_interceptors_test/my_interceptor")
    mail = BaseMailer.welcome
    BaseMailerPreview.any_instance.stubs(:welcome).returns(mail)
    MyInterceptor.expects(:previewing_email).with(mail)
    BaseMailerPreview.call(:welcome)
  end

  test "you can register multiple preview interceptors to the mail object that both get passed the mail object before previewing" do
    ActionMailer::Base.register_preview_interceptors("BasePreviewInterceptorsTest::MyInterceptor", MySecondInterceptor)
    mail = BaseMailer.welcome
    BaseMailerPreview.any_instance.stubs(:welcome).returns(mail)
    MyInterceptor.expects(:previewing_email).with(mail)
    MySecondInterceptor.expects(:previewing_email).with(mail)
    BaseMailerPreview.call(:welcome)
  end
end
