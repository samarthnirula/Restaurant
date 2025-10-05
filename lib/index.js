import Stripe from "stripe";

export default {
  async fetch(req) {
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method Not Allowed" }),
        { status: 405, headers: { "Content-Type": "application/json" } }
      );
    }

    try {
      const body = await req.json(); 
      const { amount } = body;

      if (!amount || amount <= 0) {
        return new Response(
          JSON.stringify({ error: "Invalid amount" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
      }

      const stripe = new Stripe(
        " ",
        { apiVersion: "2023-10-16" }
      );

      const paymentIntent = await stripe.paymentIntents.create({
        amount,
        currency: "usd",
        automatic_payment_methods: { enabled: true },
      });

      return new Response(
        JSON.stringify({ clientSecret: paymentIntent.client_secret }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    } catch (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }
  },
};
